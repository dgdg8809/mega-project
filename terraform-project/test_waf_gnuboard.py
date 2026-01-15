#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import requests
import time
from datetime import datetime
import sys
import os


if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except:
        pass
    os.environ['PYTHONIOENCODING'] = 'utf-8'

GNUBOARD_URL = "http://gnuboard.iac.it-edu.org/"
SESSION = requests.Session()

def print_result(test_name, response, blocked=False):
    
    status_text = "[BLOCKED]" if blocked else "[ALLOWED]"
    print(f"\n{'='*60}")
    print(f"[{test_name}] {status_text}")
    print(f"{'='*60}")
    print(f"Status Code: {response.status_code}")
    print(f"Response Time: {response.elapsed.total_seconds():.2f}s")
    print(f"URL: {response.url[:80]}...")
    if response.text:
        print(f"Response Length: {len(response.text)} bytes")
    print(f"{'='*60}\n")

def test_1_sql_injection():
    
    print("\n[테스트 1] SQL Injection 공격 시작...")
    
    sql_payloads = [
        "' OR '1'='1",
        "' OR 1=1--",
        "' UNION SELECT NULL--",
        "admin'--",
        "' OR 'x'='x",
        "1' UNION SELECT 1,2,3,4,5--",
        "' OR SLEEP(5)--",
        "1' AND '1'='1",
        "1' AND '1'='2",
        "' UNION ALL SELECT 1,2,3,4,5--",
        "' UNION SELECT NULL,NULL,NULL--",
        "admin' --",
        "admin' #",
        "' OR ''='",
        "1' OR 1=1 LIMIT 1--",
        "'; DROP TABLE users--",
        "1' AND (SELECT * FROM (SELECT(SLEEP(5)))a)--",
        "' AND 1=1",
        "' AND 1=2 UNION SELECT NULL--",
    ]
    
    blocked_count = 0
    for payload in sql_payloads:
        try:
            
            params = {
                'mb_id': payload,
                'mb_password': payload,
                'stx': payload,  # 검색어
            }
            
            response = SESSION.get(
                f"{GNUBOARD_URL}bbs/login.php",
                params=params,
                timeout=5
            )
            
            
            is_blocked = (response.status_code in [403, 405, 408, 429] or 
                         response.status_code >= 500 or
                         "blocked" in response.text.lower() or
                         "access denied" in response.text.lower() or
                         "forbidden" in response.text.lower() or
                         len(response.text) < 100)  # 비정상적으로 짧은 응답
            
            if is_blocked:
                blocked_count += 1
                print_result(f"SQL Injection: {payload[:30]}...", response, blocked=True)
            else:
                print_result(f"SQL Injection: {payload[:30]}...", response, blocked=False)
            
            time.sleep(0.5)
            
        except requests.exceptions.RequestException as e:
            print(f"[ERROR] {e}")
    
    print(f"\n[결과] SQL Injection 차단률: {blocked_count}/{len(sql_payloads)}")
    return blocked_count > 0

def test_2_common_web_attacks():
    
    print("\n[테스트 2] 일반적인 웹 공격 패턴 시작...")
    
    attack_payloads = [
        
        "<script>alert('XSS')</script>",
        "<img src=x onerror=alert('XSS')>",
        "javascript:alert('XSS')",
        "<svg onload=alert('XSS')>",
        "<iframe src=javascript:alert('XSS')>",
        "%3Cscript%3Ealert('XSS')%3C/script%3E",  
        "<body onload=alert('XSS')>",
        
        
        "../../../etc/passwd",
        "....//....//etc/passwd",
        "..%2F..%2F..%2Fetc%2Fpasswd",
    ]
    
    blocked_count = 0
    for payload in attack_payloads:
        try:
            params = {
                'stx': payload,  
                'mb_id': payload,
                'wr_subject': payload,
            }
            
            response = SESSION.get(
                GNUBOARD_URL,
                params=params,
                timeout=5
            )
            
            
            is_blocked = (response.status_code in [403, 405, 408, 429] or 
                         response.status_code >= 500 or
                         "blocked" in response.text.lower() or
                         "access denied" in response.text.lower() or
                         "forbidden" in response.text.lower() or
                         len(response.text) < 100)  
            
            if is_blocked:
                blocked_count += 1
                print_result(f"Common Attack: {payload[:30]}...", response, blocked=True)
            else:
               
                try:
                    response_path = SESSION.get(
                        f"{GNUBOARD_URL}?{payload}",
                        timeout=5
                    )
                    is_blocked_path = (response_path.status_code in [403, 405, 408, 429] or 
                                     response_path.status_code >= 500 or
                                     len(response_path.text) < 100)
                    
                    if is_blocked_path:
                        blocked_count += 1
                        print_result(f"Common Attack (PATH): {payload[:30]}...", response_path, blocked=True)
                    else:
                        print_result(f"Common Attack: {payload[:30]}...", response, blocked=False)
                except:
                    print_result(f"Common Attack: {payload[:30]}...", response, blocked=False)
            
            time.sleep(0.5)
            
        except requests.exceptions.RequestException as e:
            print(f"[ERROR] {e}")
    
    print(f"\n[결과] 일반 공격 차단률: {blocked_count}/{len(attack_payloads)}")
    return blocked_count > 0

def main():
    
    print("="*60)
    print("[GNUBoard WAF 테스트 스크립트]")
    print("="*60)
    print(f"대상 URL: {GNUBOARD_URL}")
    print(f"시작 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    results = {
        "SQL Injection": False,
        "Common Web Attacks": False,
    }
    
    try:
        results["SQL Injection"] = test_1_sql_injection()
        time.sleep(2)
        results["Common Web Attacks"] = test_2_common_web_attacks()
        
    except KeyboardInterrupt:
        print("\n\n[중단] 사용자가 테스트를 중단했습니다.")
    except Exception as e:
        print(f"\n[ERROR] 예상치 못한 에러: {e}")
    
    
    print("\n" + "="*60)
    print("[최종 테스트 결과 요약]")
    print("="*60)
    for test_name, was_blocked in results.items():
        status = "[차단 확인됨]" if was_blocked else "[차단 미확인]"
        print(f"  {test_name}: {status}")
    print("="*60)
    
    print("\n[CloudWatch] WAF 메트릭 확인:")
    print("  CloudWatch > Metrics > WAF > WebACL > seoul-waf-gnuboard")
    print(f"\n완료 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main()
