import requests
import json

def test():
    url = "https://lms2.yuktaa.com/api/v2/auth/login"
    payload = {
        "username": "9011515979",
        "password": "Pass123"
    }
    headers = {
        "Content-Type": "application/json"
    }
    try:
        r = requests.post(url, json=payload, headers=headers, verify=False, timeout=10)
        print("Status Code:", r.status_code)
        print("Response:", r.text)
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    test()
