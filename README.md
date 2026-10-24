# DevOps AWS com Terraform e Ansible

Projeto de automação de infraestrutura e configuração de ambiente na AWS usando Terraform e Ansible.

O Terraform é responsável pelo provisionamento da infraestrutura e executa o Ansible para preparar as instâncias, configurar a aplicação, website e inserir o script SQL no banco de dados.

Infraestrutura para atender aos requisitos do projeto de Pesquisa e Inovação desenvolvido durante o 3° e 4° semestre do curso de Bacharelado em Ciências da Computação na São Paulo Tech School. [Organização no GitHub com os repositórios do projeto.](https://github.com/pezao-sound-projeto-de-extensao)

## Arquitetura

<img width="1246" height="1326" alt="Diagrama DevOps drawio" src="https://github.com/user-attachments/assets/d18d5bc7-f89b-4ffd-8522-f8d8434bc1d5" />

## Estrutura do repositório

```bash
.
├── dev
│   ├── docker-compose.yml
│   └── nginx.conf
└── prod
    ├── ansible
    │   ├── ansible.cfg
    │   ├── inventories/production    # gerado pelo Terraform
    │   ├── playbooks
    │   │   ├── db.yml
    │   │   └── deploy.yml
    │   └── roles
    │       ├── app
    │       └── db
    └── terraform
```

## Ambientes

- `dev`: stack local com Docker Compose (app, web, MySQL, RabbitMQ, Floci como S3 e Mailpit).
- `prod`: infraestrutura na AWS criada pelo Terraform e configurada pelo Ansible.

## Arquitetura de produção

- Duas AZs. Em cada uma há uma instância de back (app) e uma de front (web).
- Cada AZ tem seu próprio Docker Swarm: a instância app é o manager e a web é o worker.
- O back (API com 2 réplicas, nginx, RabbitMQ e Fluent Bit) roda no manager; o front roda no worker.
- O ALB envia `/api` para as instâncias app e o resto para as instâncias web.
- As imagens ficam no ECR (`pezao-sound-api` e `pezao-sound-web`).
- Banco no RDS MySQL (multi-AZ) e arquivos e logs no S3.

## Como subir

Pré-requisitos na máquina que roda o Terraform: Terraform, Ansible, AWS CLI e GitHub CLI.

1. Coloque as credenciais da sessão da AWS em `~/.aws/credentials`.
2. Faça login no GitHub CLI (uma vez): `gh auth login`. A conta precisa poder criar secrets e rodar Actions nos repositórios Back-end e Front-end.
3. Rode:

```bash
cd prod/terraform
terraform init
terraform apply -auto-approve
```

O que acontece durante o apply:

1. São criados a rede, as instâncias, o RDS e os repositórios do ECR.
2. Assim que o ECR existe, o Terraform grava as credenciais da AWS como secrets nos repositórios do GitHub e dispara o workflow `ecr.yml` do Back-end e do Front-end, que fazem o build e enviam as imagens para o ECR. Isso roda enquanto o RDS é criado.
3. Com o RDS pronto, o Ansible roda o script do banco (`db.yml`).
4. Com o banco e as imagens prontos, o Ansible (`deploy.yml`) instala o Docker, cria os swarms e faz o deploy da stack.

## Como destruir

```bash
cd prod/terraform
terraform destroy -auto-approve
```
