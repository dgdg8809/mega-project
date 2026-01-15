#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import requests
import time
from datetime import datetime
import json
import sys
import os


if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except:
        pass
    os.environ['PYTHONIOENCODING'] = 'utf-8'

DVWA_URL = "http://dvwa.iac.it-edu.org/dvwa"
SESSION = requests.Session()

def print_result(test_name, response, blocked=False):
    
    status_text = "[BLOCKED]" if blocked else "[ALLOWED]"
    print(f"\n{'='*60}")
    print(f"[{test_name}] {status_text}")
    print(f"{'='*60}")
    print(f"Status Code: {response.status_code}")
    print(f"Response Time: {response.elapsed.total_seconds():.2f}s")
    print(f"URL: {response.url}")
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
    ]
    
    blocked_count = 0
    for payload in sql_payloads:
        try:
            
            params = {
                'id': payload,
                'username': payload,
                'password': payload,
            }
            
            
            response = SESSION.get(
                f"{DVWA_URL}vulnerabilities/sqli/?id={payload}",
                params=params,
                timeout=5
            )
            
            
            is_blocked = response.status_code in [403, 405] or "blocked" in response.text.lower()
            
            if is_blocked:
                blocked_count += 1
                print_result(f"SQL Injection: {payload[:30]}...", response, blocked=True)
            else:
                print_result(f"SQL Injection: {payload[:30]}...", response, blocked=False)
            
            time.sleep(0.5)  # Rate limit 회피
            
        except requests.exceptions.RequestException as e:
            print(f"[ERROR] {e}")
    
    print(f"\n[결과] SQL Injection 차단률: {blocked_count}/{len(sql_payloads)}")
    return blocked_count > 0

def check_cloudwatch_metrics():
    
    print("\n" + "="*60)
    print("[CloudWatch] WAF 메트릭 확인 방법")
    print("="*60)
    print("""
          
AWS 콘솔에서 다음 경로로 이동하세요:

1. CloudWatch > Metrics > WAF > WebACL
2. 다음 메트릭을 확인하세요:
   - CountedRequests: 허용된 요청 수
   - BlockedRequests: 차단된 요청 수
   - AllowedRequests: 명시적으로 허용된 요청 수

필터:
   - WebACL: seoul-waf-dvwa
   - Rule: AWSManagedRulesSQLiRuleSet

3. WAF 로그 확인:
   - CloudWatch Logs > Log groups > /aws/waf/seoul-waf-dvwa

로그에서 "action": "BLOCK"인 항목을 찾으면 차단된 요청을 확인할 수 있습니다.
    """)

def main():
    
    print("="*60)
    print("[DVWA WAF 테스트 스크립트]")
    print("="*60)
    print(f"대상 URL: {DVWA_URL}")
    print(f"시작 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    try:
        
        was_blocked = test_1_sql_injection()
        
        
        print("\n" + "="*60)
        print("[최종 테스트 결과 요약]")
        print("="*60)
        status = "[차단 확인됨]" if was_blocked else "[차단 미확인]"
        print(f"  SQL Injection: {status}")
        print("="*60)
        
    except KeyboardInterrupt:
        print("\n\n[중단] 사용자가 테스트를 중단했습니다.")
    except Exception as e:
        print(f"\n[ERROR] 예상치 못한 에러: {e}")
    
    
    check_cloudwatch_metrics()
    
    print(f"\n완료 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main()
