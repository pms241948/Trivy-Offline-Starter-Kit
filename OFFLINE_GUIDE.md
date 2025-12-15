# 오프라인 SBOM 생성 가이드

이 가이드는 폐쇄망(인터넷이 차단된) 리눅스 서버에서 SBOM 생성 도구를 실행하는 방법을 설명합니다.

## 전제 조건

- 리눅스 서버에 **Docker**가 설치되어 있어야 합니다.
- 인터넷이 가능한 PC에서 `prepare_offline.sh`를 사용하여 필요한 파일들을 미리 준비해야 합니다.

## 0단계: 준비 작업 (인터넷 가능 PC)

인터넷이 연결된 PC(예: 맥북, 개인 PC)에서 다음 과정을 수행하여 필요한 파일들을 다운로드하고 압축합니다.

1. 이 프로젝트를 다운로드(git clone) 합니다.
2. 터미널에서 준비 스크립트를 실행합니다.
   ```bash
   ./prepare_offline.sh
   # 실행이 완료되면 'trivy_offline_assets' 폴더에 파일들이 생성됩니다.
   ```

## 1단계: 파일 전송

다음 파일들을 폐쇄망 리눅스 서버로 이동시킵니다 (USB, 보안 파일 전송 등 이용). 모든 파일을 하나의 디렉토리(예: `/app/trivy-sbom`)에 모아두세요.

1. `generate_sbom.sh` (메인 스캔 스크립트)
2. `trivy_image.tar` (Docker 이미지 파일)
3. `trivy_cache.tar.gz` (취약점 데이터베이스 압축 파일)

## 2단계: Docker 이미지 로드

서버의 로컬 Docker 레지스트리에 Trivy 이미지를 로드합니다.

```bash
docker load -i trivy_image.tar
```

이미지가 정상적으로 로드되었는지 확인합니다:

```bash
docker images
# 목록에 'aquasec/trivy'가 보여야 합니다.
```

## 3단계: 데이터베이스 캐시 압축 해제

데이터베이스 캐시 파일의 압축을 풉니다. `generate_sbom.sh` 스크립트는 실행 위치에 `trivy-cache`라는 폴더가 있어야 동작합니다.

```bash
tar -xzf trivy_cache.tar.gz
```

`trivy-cache` 디렉토리가 생성되었는지 확인합니다:

```bash
ls -d trivy-cache
# 출력 결과: trivy-cache
```

## 4단계: SBOM 생성 실행

스크립트에 실행 권한을 부여합니다:

```bash
chmod +x generate_sbom.sh
```

스캔할 대상 경로를 지정하여 스크립트를 실행합니다.

**예시 1: 단일 파일 스캔**
```bash
./generate_sbom.sh /path/to/your/app.jar
```

**예시 2: 프로젝트 전체 스캔 (권장)**
폴더를 지정하면, 해당 폴더 전체를 하나의 프로젝트로 인식하여 **통합 SBOM**을 생성합니다.
```bash
./generate_sbom.sh /path/to/your/project_source
```

## 결과물 확인

생성된 SBOM 파일(JSON)은 아래 경로에 저장됩니다:
`/app/trivy-sbom/output/[YYYYMMDD]/`

(참고: output 디렉토리에 쓰기 권한이 있는지 확인하세요)
