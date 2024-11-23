# ECS Cluster

* Web - https://github.com/ttabae/WePLAT-Frontend.git
* Applicant - https://github.com/ttabae/WePLAT-Backend-Applicant.git  
* JobPosting - https://github.com/ttabae/WePLAT-Backend-Jobposting.git

---

## Issue

1. SpringBoot H2 문제
    * 도커데몬으로 돌렸을때는 문제없던 이미지가 ECS 에서 실행시 h2 DB 관련 문제발생 
        * 해결법   
            * 원본소스에서 H2 com/job/config/DatabaseConfiguration.class 에 있는 h2TCPServer 주석처리함
            * 이외에도 프로파일 바꾸거나 하면 될듯
