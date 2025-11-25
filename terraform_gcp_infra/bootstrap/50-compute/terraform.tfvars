# 50-compute 레이어 설정

# Jenkins VM 설정
jenkins_machine_type = "e2-medium"
jenkins_image        = "debian-cloud/debian-12"
jenkins_disk_size    = 50

# 존 설정
zone = "asia-northeast3-a"

# 네트워크 설정
assign_external_ip = true
create_static_ip   = false

# 추가 디스크 (필요시 true로 변경)
create_data_disk = false
data_disk_size   = 100

# 보안 설정
deletion_protection = true
