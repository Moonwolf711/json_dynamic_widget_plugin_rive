#!/usr/bin/env python3
"""Hot reload trigger for Flutter app via VM Service"""
import asyncio
import json
import sys

try:
    import websockets
except ImportError:
    print("Installing websockets...")
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "websockets", "-q"])
    import websockets

async def hot_reload(vm_url: str):
    # Convert HTTP URL to WebSocket URL
    ws_url = vm_url.replace("http://", "ws://").rstrip("/") + "/ws"
    print(f"Connecting to {ws_url}...")

    try:
        async with websockets.connect(ws_url) as ws:
            # Get VM info first to find isolate
            await ws.send(json.dumps({
                "jsonrpc": "2.0",
                "id": "1",
                "method": "getVM"
            }))
            response = json.loads(await ws.recv())

            if "result" in response and "isolates" in response["result"]:
                isolates = response["result"]["isolates"]
                if isolates:
                    isolate_id = isolates[0]["id"]
                    print(f"Found isolate: {isolate_id}")

                    # Trigger hot reload
                    await ws.send(json.dumps({
                        "jsonrpc": "2.0",
                        "id": "2",
                        "method": "reloadSources",
                        "params": {"isolateId": isolate_id}
                    }))
                    reload_response = json.loads(await ws.recv())

                    if "result" in reload_response:
                        print("Hot reload successful!")
                    else:
                        print(f"Reload response: {reload_response}")
            else:
                print(f"Unexpected response: {response}")

    except Exception as e:
        print(f"Error: {e}")

def find_vm_url():
    """Find VM URL from flutter output or saved file"""
    import glob
    import re

    # Try saved file first
    try:
        with open("C:\\wfl\\.flutter_vm_url", "r") as f:
            url = f.read().strip()
            if url:
                return url
    except:
        pass

    # Try to find from flutter output files
    output_files = glob.glob("/tmp/claude/-home-moon-wolf/tasks/*.output")
    for path in output_files:
        try:
            with open(path, "r") as f:
                content = f.read()
                match = re.search(r'Dart VM Service.*?at:\s*(http://[^\s]+)', content)
                if match:
                    return match.group(1)
        except:
            pass

    return None

if __name__ == "__main__":
    vm_url = find_vm_url()
    if not vm_url:
        print("Could not find VM URL. Is the app running?")
        sys.exit(1)

    print(f"Using VM URL: {vm_url}")
    asyncio.run(hot_reload(vm_url))
