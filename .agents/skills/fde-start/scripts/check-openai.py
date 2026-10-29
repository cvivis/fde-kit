"""OpenAI 연결 확인: 환경변수 존재, 모델 목록, 간단한 호출. 값은 출력하지 않는다.
사용: python kit/scripts/check-openai.py
"""
import os
import sys

for key in ("OPENAI_API_KEY", "OPENAI_BASE_URL"):
    print(f"{key}: {'설정됨' if os.environ.get(key) else '없음'}")

try:
    from openai import OpenAI
except ImportError:
    sys.exit("openai 패키지 없음: pip install openai")

client = OpenAI()
try:
    models = sorted(m.id for m in client.models.list())
    print(f"사용 가능한 모델 {len(models)}개:")
    for m in models:
        print("  -", m)
except Exception as e:  # 프록시가 목록 조회를 막을 수 있음
    print("모델 목록 조회 실패:", type(e).__name__, e)
