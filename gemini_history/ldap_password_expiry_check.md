# LDAP 패스워드 만료일 확인 대화 기록

## Q: phpldapadmin에서 패스워드 만료일을 어떻게 확인하나요?

A: `ldapsearch` 명령어를 사용하여 사용자의 `pwdChangedTime` 속성과 패스워드 정책(`ppolicy`)의 `pwdMaxAge` 속성을 확인하여 계산할 수 있습니다.

- **사용자 패스워드 마지막 변경일 확인:**
  ```bash
  ldapsearch -x -b "ou=people,dc=example,dc=com" "(uid=사용자ID)" pwdChangedTime
  ```

- **적용된 패스워드 정책 확인:**
  ```bash
  ldapsearch -x -b "ou=people,dc=example,dc=com" "(uid=사용자ID)" pwdPolicySubentry
  ```

- **패스워드 최대 유효 기간 확인:**
  ```bash
  ldapsearch -x -b "cn=default,ou=policies,dc=example,dc=com" -s base "(objectclass=*)" pwdMaxAge
  ```

## Q: 이미 패스워드를 변경해서 이전 만료일이 확인되지 않습니다. 어떻게 확인하나요?

A: LDAP 서버 로그(`slapd.log` 등)를 확인하는 것이 가장 현실적인 방법입니다. 로그에서 패스워드 변경(`modify`) 기록이나 만료 경고(`ppolicy_bind: Setting warning`) 로그를 찾아 이전 변경 시점이나 남은 유효 기간을 역추적할 수 있습니다.

## Q: 아래 로그가 있는데, 원래 만료일이 언제였나요?
> Jun 22 04:00:01 qa-ldap01 slapd[1434]: ppolicy_bind: Setting warning for password expiry for uid=toor,ou=Users,dc=fttcorp,dc=com = 479501 seconds

A: 해당 로그는 **6월 22일 04:00:01** 기준으로 패스워드 만료까지 **479501초(약 5.55일)**가 남았다는 의미입니다.

계산 결과, 원래 패스워드 만료일은 **6월 27일 17시 11분 42초**였습니다.
