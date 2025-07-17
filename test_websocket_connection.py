#!/usr/bin/env python3
"""
WebSocket connection test for Piano Game Server
"""
import asyncio
import websockets
import json
import time
from datetime import datetime

SERVER_URL = "wss://finalproj-piano-game.uc.r.appspot.com"
HTTP_SERVER_URL = "https://finalproj-piano-game.uc.r.appspot.com"

class WebSocketTester:
    def __init__(self):
        self.connected = False
        self.messages_received = []
        self.test_results = []
        
    def log_result(self, test_name, success, message=""):
        """Log test result"""
        status = "✅ PASS" if success else "❌ FAIL"
        result = f"{test_name}: {status}"
        if message:
            result += f" - {message}"
        print(result)
        self.test_results.append((test_name, success, message))
        
    async def test_websocket_connection(self):
        """Test basic WebSocket connection"""
        try:
            print(f"Attempting to connect to {SERVER_URL}")
            
            # Try to connect with Socket.IO path
            socketio_url = f"{SERVER_URL}/socket.io/?EIO=4&transport=websocket"
            
            async with websockets.connect(socketio_url) as websocket:
                self.connected = True
                self.log_result("WebSocket Connection", True, "Connected successfully")
                
                # Send a test message
                await websocket.send("40")  # Socket.IO connect message
                
                # Wait for response
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    self.log_result("WebSocket Response", True, f"Received: {response}")
                    self.messages_received.append(response)
                except asyncio.TimeoutError:
                    self.log_result("WebSocket Response", False, "Timeout waiting for response")
                    
        except Exception as e:
            self.log_result("WebSocket Connection", False, f"Connection failed: {str(e)}")
            
    async def test_socketio_connection(self):
        """Test Socket.IO connection"""
        try:
            import socketio
            
            print(f"Testing Socket.IO connection to {HTTP_SERVER_URL}")
            
            sio = socketio.AsyncClient()
            
            @sio.event
            async def connect():
                print("Socket.IO connected!")
                self.log_result("Socket.IO Connection", True, "Connected successfully")
                
            @sio.event
            async def disconnect():
                print("Socket.IO disconnected!")
                
            @sio.event
            async def connect_response(data):
                print(f"Connect response: {data}")
                self.log_result("Socket.IO Response", True, f"Received: {data}")
                
            # Connect to the server
            await sio.connect(HTTP_SERVER_URL)
            
            # Wait a bit to see if we get responses
            await asyncio.sleep(2)
            
            # Test a simple event
            await sio.emit('test_event', {'message': 'Hello from test client'})
            
            # Wait for any responses
            await asyncio.sleep(2)
            
            await sio.disconnect()
            
        except ImportError:
            self.log_result("Socket.IO Connection", False, "python-socketio not installed")
            print("To install: pip install python-socketio")
        except Exception as e:
            self.log_result("Socket.IO Connection", False, f"Connection failed: {str(e)}")
            
    async def test_http_upgrade(self):
        """Test HTTP to WebSocket upgrade"""
        try:
            import aiohttp
            
            async with aiohttp.ClientSession() as session:
                async with session.ws_connect(f"{SERVER_URL}/socket.io/?EIO=4&transport=websocket") as ws:
                    self.log_result("HTTP Upgrade", True, "WebSocket upgrade successful")
                    
                    # Send Socket.IO connect message
                    await ws.send_str("40")
                    
                    # Wait for response
                    try:
                        msg = await asyncio.wait_for(ws.receive(), timeout=5.0)
                        self.log_result("Upgrade Response", True, f"Received: {msg.data}")
                    except asyncio.TimeoutError:
                        self.log_result("Upgrade Response", False, "Timeout waiting for response")
                        
        except ImportError:
            self.log_result("HTTP Upgrade", False, "aiohttp not installed")
            print("To install: pip install aiohttp")
        except Exception as e:
            self.log_result("HTTP Upgrade", False, f"Upgrade failed: {str(e)}")
            
    async def run_all_tests(self):
        """Run all WebSocket tests"""
        print("WebSocket Connection Testing")
        print("=" * 50)
        print(f"Target server: {SERVER_URL}")
        print(f"HTTP server: {HTTP_SERVER_URL}")
        print(f"Test started at: {datetime.now()}")
        print()
        
        # Test 1: Basic WebSocket connection
        print("Test 1: Basic WebSocket Connection")
        await self.test_websocket_connection()
        print()
        
        # Test 2: Socket.IO connection
        print("Test 2: Socket.IO Connection")
        await self.test_socketio_connection()
        print()
        
        # Test 3: HTTP to WebSocket upgrade
        print("Test 3: HTTP to WebSocket Upgrade")
        await self.test_http_upgrade()
        print()
        
        # Summary
        print("=" * 50)
        print("Test Summary:")
        passed = sum(1 for _, success, _ in self.test_results if success)
        total = len(self.test_results)
        
        for test_name, success, message in self.test_results:
            status = "✅ PASS" if success else "❌ FAIL"
            print(f"{test_name}: {status}")
            if message and not success:
                print(f"  Error: {message}")
                
        print(f"\nResults: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 All WebSocket tests passed!")
        else:
            print("⚠️  Some tests failed - check server configuration")
            
        return passed == total

async def main():
    tester = WebSocketTester()
    success = await tester.run_all_tests()
    return success

if __name__ == "__main__":
    success = asyncio.run(main())
    exit(0 if success else 1)