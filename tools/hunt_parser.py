#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Hunt: Showdown 1896 - attributes.xml 战绩解析与实时同步客户端
依赖安装: pip install watchdog requests
"""

import os
import sys
import time
import json
import hashlib
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional

try:
    import requests
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
except ImportError:
    print("[-] 缺少必要依赖，请运行: pip install watchdog requests")
    sys.exit(1)


# ================= 配置区 =================
# 游戏 AppID
APP_ID = "594650"

# 后端上传接收接口（如果仅本地测试，可保持 None）
BACKEND_API_URL = os.getenv("HUNT_SYNC_URL", None)  # 如: "http://localhost:8080/api/v1/matches/sync"
API_AUTH_TOKEN = os.getenv("HUNT_SYNC_TOKEN", "")

# 本地调试 JSON 输出目录
OUTPUT_DIR = Path("./parsed_matches")
OUTPUT_DIR.mkdir(exist_ok=True)
# ==========================================


def find_attributes_xml_path() -> Optional[Path]:
    """
    自动探测不同盘符和 Steam 库目录下的 attributes.xml 路径
    """
    candidate_roots = [
        r"C:\Program Files (x86)\Steam",
        r"D:\SteamLibrary",
        r"E:\SteamLibrary",
        r"F:\SteamLibrary",
    ]
    
    # 相对安装路径
    rel_path = Path("steamapps/common/Hunt Showdown/user/game.cfg") # 基础目录
    xml_subpath = Path("steamapps/common/Hunt Showdown/user/profiles/default/attributes.xml")

    for root in candidate_roots:
        target = Path(root) / xml_subpath
        if target.exists():
            return target

    # 如果默认路径没找到，支持环境变量或当前输入
    env_path = os.getenv("HUNT_ATTRIBUTES_PATH")
    if env_path and Path(env_path).exists():
        return Path(env_path)

    return None


class HuntMatchParser:
    """解析 attributes.xml 的扁平键值对"""

    @staticmethod
    def parse_file(file_path: Path) -> Optional[Dict[str, Any]]:
        if not file_path.exists():
            return None

        try:
            tree = ET.parse(file_path)
            root = tree.getroot()
        except ET.ParseError as e:
            print(f"[-] XML 解析失败 (可能游戏正在写入中): {e}")
            return None

        # attributes.xml 格式为: <Attr name="MissionBagPlayer_0_0_name" value="..." />
        attr_map: Dict[str, str] = {}
        for elem in root.findall(".//Attr"):
            name = elem.get("name")
            val = elem.get("value")
            if name is not None:
                attr_map[name] = val or ""

        if not attr_map:
            return None

        # 检查是否包含结算标志
        # MissionBagIsQuickPlay / MissionBagIsHunterDead
        is_hunter_dead = attr_map.get("MissionBagIsHunterDead", "false").lower() == "true"
        is_extracted = attr_map.get("MissionBagIsExtract", "false").lower() == "true" or not is_hunter_dead

        # 击杀与战绩统计
        kills = int(attr_map.get("MissionBagNumKills", "0") or 0)
        team_kills = int(attr_map.get("MissionBagTeamKills", "0") or 0)
        deaths = 1 if is_hunter_dead else 0
        assists = int(attr_map.get("MissionBagNumAssists", "0") or 0)
        bounty = int(attr_map.get("MissionBagBounty", "0") or 0)
        team_wipes = int(attr_map.get("MissionBagTeamWipes", "0") or 0)

        # MMR星级及评分
        mmr = int(attr_map.get("MissionBagPlayerMMR", "0") or 0)
        mmr_change = int(attr_map.get("MissionBagPlayerMMRChange", "0") or 0)

        # 地图与模式
        map_name = attr_map.get("MissionBagMapName", "Unknown Map")
        game_mode = "Bounty Hunt" if attr_map.get("MissionBagIsQuickPlay", "0") == "0" else "Soul Survivor"

        # 生成该局唯一指纹 (通过提取时间、击杀、玩家名生成 Hash)
        timestamp = datetime.utcnow().isoformat() + "Z"
        raw_sig = f"{timestamp}_{kills}_{deaths}_{bounty}_{mmr}"
        match_id = hashlib.md5(raw_sig.encode()).hexdigest()[:16]

        # 提取遭遇的玩家/队伍列表
        entries = []
        entry_idx = 0
        while True:
            p_name_key = f"MissionBagPlayer_{entry_idx}_name"
            if p_name_key not in attr_map:
                break
            p_name = attr_map[p_name_key]
            p_mmr = attr_map.get(f"MissionBagPlayer_{entry_idx}_mmr", "0")
            p_killed = attr_map.get(f"MissionBagPlayer_{entry_idx}_downed_by_me", "0")
            entries.append({
                "name": p_name,
                "mmr": int(p_mmr) if p_mmr.isdigit() else 0,
                "downed_by_me": int(p_killed) if p_killed.isdigit() else 0,
            })
            entry_idx += 1

        match_data = {
            "match_id": match_id,
            "match_time": timestamp,
            "game_mode": game_mode,
            "map_name": map_name,
            "extracted": is_extracted,
            "kills": kills,
            "deaths": deaths,
            "assists": assists,
            "team_wipes": team_wipes,
            "bounty_extracted": bounty,
            "mmr": mmr,
            "mmr_change": mmr_change,
            "encountered_players": entries,
        }

        return match_data


class MatchFileWatcher(FileSystemEventHandler):
    def __init__(self, target_file: Path):
        self.target_file = target_file
        self.last_hash = ""

    def on_modified(self, event):
        # 排除非目标文件
        if Path(event.src_path).resolve() != self.target_file.resolve():
            return

        # 等待写盘完成，防文件锁冲突
        time.sleep(1.5)

        # 检查文件 MD5 避免重复触发
        try:
            with open(self.target_file, "rb") as f:
                content = f.read()
                cur_hash = hashlib.md5(content).hexdigest()
                if cur_hash == self.last_hash:
                    return
                self.last_hash = cur_hash
        except Exception:
            return

        print(f"\n[+] 检测到战绩变动: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        parsed_data = HuntMatchParser.parse_file(self.target_file)
        if not parsed_data:
            print("[-] 解析结果为空或数据未就绪")
            return

        print(f"[+] 解析成功: 地图={parsed_data['map_name']}, 击杀={parsed_data['kills']}, 存活={parsed_data['extracted']}, 赏金={parsed_data['bounty_extracted']}")

        # 1. 保存到本地 JSON
        out_file = OUTPUT_DIR / f"match_{parsed_data['match_id']}.json"
        with open(out_file, "w", encoding="utf-8") as f:
            json.dump(parsed_data, f, ensure_ascii=False, indent=2)
        print(f"[+] 已暂存本地: {out_file}")

        # 2. 上报服务器（如果配置了 URL）
        if BACKEND_API_URL:
            self._send_to_backend(parsed_data)

    def _send_to_backend(self, payload: Dict[str, Any]):
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {API_AUTH_TOKEN}"
        }
        try:
            resp = requests.post(BACKEND_API_URL, json=payload, headers=headers, timeout=5)
            if resp.status_code in (200, 201):
                print("[+] 成功同步至后端 API 服务器")
            else:
                print(f"[-] 同步失败, 状态码: {resp.status_code}, 响应: {resp.text}")
        except Exception as e:
            print(f"[-] 上传异常: {e}")


def main():
    print("=" * 60)
    print("  Hunt: Showdown 1896 战绩同步监听服务 (attributes.xml)")
    print("=" * 60)

    xml_path = find_attributes_xml_path()
    if not xml_path:
        print("[-] 未在默认目录找到 attributes.xml。")
        user_input = input("请输入 attributes.xml 的完整绝对路径: ").strip()
        xml_path = Path(user_input)
        if not xml_path.exists():
            print("[-] 路径无效，退出程序。")
            return

    print(f"[+] 正在监听目标文件: {xml_path}")
    print("[*] 正在解析当前最新一场战绩...")
    init_match = HuntMatchParser.parse_file(xml_path)
    if init_match:
        print(f"[*] 最近对局预览: {json.dumps(init_match, ensure_ascii=False, indent=2)}")

    # 启动文件监听
    event_handler = MatchFileWatcher(xml_path)
    observer = Observer()
    observer.schedule(event_handler, path=str(xml_path.parent), recursive=False)
    observer.start()

    print("\n[*] 服务运行中 (后台检测中，对局结算后将自动触发解析并导出 JSON)... 按 Ctrl+C 退出。")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\n[*] 监听已停止。")
    observer.join()


if __name__ == "__main__":
    main()