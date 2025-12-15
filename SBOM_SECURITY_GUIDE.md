# SBOM 주요 보안 요소 가이드

본 문서는 **CycloneDX 포맷**으로 생성된 SBOM(Software Bill of Materials) 파일 내에서, 중점적으로 확인해야 할 주요 필드와 그 의미를 설명합니다.

## 1. SBOM 구조 개요 (JSON)

일반적인 CycloneDX JSON 파일은 크게 `metadata` (메타데이터), `components` (구성요소), `dependencies` (의존성 관계), `vulnerabilities` (취약점) 섹션으로 나뉩니다.

## 2. 주요 보안 요소 상세 (표)

| 구분 | JSON 필드명 (Key) | 의미 및 보안적 중요성 | 활용 예시 |
| :--- | :--- | :--- | :--- |
| **기본 정보** | `bomFormat` | SBOM 표준 포맷 (CycloneDX 등) | 도구 호환성 확인 |
| | `specVersion` | 포맷의 버전 (예: 1.4, 1.5) | 파싱 도구 버전 맞춤 |
| **메타데이터** | `metadata.component` | **분석 대상 자체** (Root Service) 정보 | 어떤 서비스의 심장부인지 식별 |
| | `metadata.timestamp` | SBOM 생성 시각 | **자산 현행화 여부** 판단 (너무 오래된 SBOM은 위험) |
| **구성요소** | `components[].name` | 라이브러리/패키지 이름 | **자산 식별** (예: `log4j-core`) |
| | `components[].version` | 설치된 버전 | **취약점 매칭**의 핵심 키 (예: `2.14.1`은 취약) |
| | `components[].purl` | **Package URL** (고유 식별자) | 전 세계 유일 식별자로 **오탐 방지** (예: `pkg:maven/org.apache...`) |
| | `components[].type` | 유형 (`library`, `framework` 등) | 자산 분류 및 중요도 산정 |
| **라이선스** | `components[].licenses` | 라이선스 정보 (Apache-2.0, GPL 등) | **법적 리스크** (Open Source Compliance) 검토 |
| **무결성** | `components[].hashes` | 파일 해시값 (SHA-256 등) | **파일 변조 여부** 확인 및 정품 인증 |
| **의존성** | `dependencies[]` | 패키지 간의 관계 (트리 구조) | **영향도 분석** (A가 뚫리면 B도 위험한가?) |
| **취약점**<br>*(옵션)* | `vulnerabilities[].id` | CVE ID (예: `CVE-2021-44228`) | 알려진 취약점 식별 |
| | `vulnerabilities[].ratings` | 위험도 점수 (CVSS Score, Severity) | **조치 우선순위** 결정 (Critical, High 등) |
| | `vulnerabilities[].recommendation` | 조치 방안 (버전 업그레이드 등) | 대응 가이드 제공 |

---

## 3. 보안 체크리스트

1.  **현행화 확인**: `timestamp`가 최근(최소 1주일 이내)인가?
2.  **자산 식별**: `components` 목록에 우리 서비스가 실제로 쓰지 않는 불필요한 라이브러리가 포함되어 있지는 않은가?
3.  **버전 노후화**: `version`이 너무 낮아 더 이상 보안 패치가 지원되지 않는(EOL) 컴포넌트가 있는가?
4.  **라이선스 위반**: `GPL` 등 소스 공개 의무가 있는 라이브러리가 상용 서비스에 포함되었는가?
5.  **무결성 검증**: 중요 라이브러리의 `hashes` 값이 공식 저장소의 값과 일치하는가?

## 4. 참고 사항 (Trivy 설정)

현재 스크립트는 `--format cyclonedx` 옵션을 사용하므로, 기본적으로 **자산 목록 (`components`)** 위주로 생성됩니다.
CVE와 같은 구체적인 취약점 정보(`vulnerabilities`)까지 포함하려면 Trivy 실행 시 `--scanners vuln` 옵션이 명시적으로 활성화되어야 합니다.
*(현재 스크립트는 이 옵션이 포함되어 있어 취약점 정보도 함께 출력될 수 있습니다)*
