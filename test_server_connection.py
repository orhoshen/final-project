#!/usr/bin/env python3
"""
Simple test script to verify server connection
"""
import requests
import json
import time

SERVER_URL = "https://finalproj-piano-game.uc.r.appspot.com"

def test_health():
    """Test health endpoint"""
    try:
        response = requests.get(f"{SERVER_URL}/api/health")
        print(f"Health endpoint: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"Health endpoint failed: {e}")
        return False

def test_compare_melodies():
    """Test compare melodies endpoint"""
    try:
        data = {
            "melody1": [60, 62, 64],
            "melody2": [60, 62, 64],
            "timings1": [0, 500, 1000],
            "timings2": [0, 500, 1000],
            "durations1": [450, 450, 450],
            "durations2": [450, 450, 450]
        }
        
        response = requests.post(f"{SERVER_URL}/api/compare-melodies", 
                               json=data, 
                               headers={"Content-Type": "application/json"})
        print(f"Compare melodies endpoint: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"Score: {result['result']['final_score']}")
            print(f"Processing time: {result['result']['matching_runtime_nocom']:.2f}ms")
            return True
        else:
            print(f"Error: {response.text}")
            return False
    except Exception as e:
        print(f"Compare melodies endpoint failed: {e}")
        return False

def test_static_files():
    """Test static files endpoint"""
    try:
        response = requests.get(f"{SERVER_URL}/static/melodies.json")
        print(f"Static files endpoint: {response.status_code}")
        if response.status_code == 200:
            melodies = response.json()
            print(f"Found {len(melodies['melodies'])} melodies")
            return True
        else:
            print(f"Error: {response.text}")
            return False
    except Exception as e:
        print(f"Static files endpoint failed: {e}")
        return False

def main():
    print("Testing server connectivity...")
    print("=" * 50)
    
    tests = [
        ("Health Check", test_health),
        ("Compare Melodies", test_compare_melodies),
        ("Static Files", test_static_files)
    ]
    
    results = []
    for name, test_func in tests:
        print(f"\nTesting {name}...")
        start_time = time.time()
        success = test_func()
        end_time = time.time()
        results.append((name, success, end_time - start_time))
        print(f"Result: {'✅ PASS' if success else '❌ FAIL'} ({end_time - start_time:.2f}s)")
    
    print("\n" + "=" * 50)
    print("Summary:")
    for name, success, duration in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{name}: {status} ({duration:.2f}s)")
    
    all_passed = all(result[1] for result in results)
    print(f"\nOverall: {'✅ ALL TESTS PASSED' if all_passed else '❌ SOME TESTS FAILED'}")

if __name__ == "__main__":
    main()