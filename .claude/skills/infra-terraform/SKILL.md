---
name: infra-terraform
description: Terraformのベストプラクティスに従い、安全でスケーラブルなインフラストラクチャをコードとして管理します。モジュール化、状態管理、セキュリティを重視したIaC実装に自動適用されます。
metadata:
  context: terraform, infrastructure, iac, aws, gcp, azure
  auto-trigger: true
---

# Infrastructure as Code with Terraform

## 概要

このスキルは、Terraformによるインフラストラクチャ管理のベストプラクティスを提供します。モジュール設計、状態管理、セキュリティ、CI/CD統合を重視し、信頼性の高いインフラストラクチャを構築します。

## 自動トリガー条件

以下の場合に自動的にこのスキルが適用されます:

- Terraformファイル (`.tf`, `.tfvars`) の作成・編集
- インフラストラクチャのプロビジョニング
- クラウドリソース管理
- "インフラ構築"、"Terraform"などのキーワード

## プロジェクト構造

### ルートモジュール構造

```bash
terraform-project/
├── environments/              # 環境別ルートモジュール
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   └── ...
│   └── prod/
│       └── ...
├── modules/                   # 再利用可能なモジュール
│   ├── network/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── compute/
│   │   └── ...
│   └── database/
│       └── ...
├── .terraform.lock.hcl       # プロバイダーバージョンロック
├── .gitignore
└── README.md
```

### ファイル命名規則

- `main.tf` - メインリソース定義
- `variables.tf` - 入力変数定義
- `outputs.tf` - 出力値定義
- `versions.tf` - Terraform/プロバイダーバージョン
- `backend.tf` - リモートバックエンド設定
- `data.tf` - データソース定義（オプション）
- `locals.tf` - ローカル変数定義（オプション）

## モジュール設計原則

### 1. 標準モジュール構造

```hcl
# modules/network/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-vpc"
    }
  )
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-public-subnet-${count.index + 1}"
      Type = "public"
    }
  )
}

# modules/network/variables.tf
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  validation {
    condition = alltrue([
      for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))
    ])
    error_message = "All subnet CIDRs must be valid CIDR blocks."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# modules/network/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}
```

### 2. モジュール呼び出し

```hcl
# environments/prod/main.tf
module "network" {
  source = "../../modules/network"

  environment          = "prod"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  availability_zones   = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]

  tags = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  environment    = "prod"
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.public_subnet_ids
  instance_type  = "t3.medium"

  tags = local.common_tags
}
```

## 状態管理ベストプラクティス

### 1. リモートバックエンド設定 (S3 + DynamoDB)

```hcl
# environments/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state-prod"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-prod"

    # バージョニング有効化を推奨
    versioning     = true
  }
}
```

### 2. 状態ファイル分離

```bash
# 環境ごとに分離
environments/
├── dev/     # dev環境の状態
├── staging/ # staging環境の状態
└── prod/    # prod環境の状態（最も厳格な管理）

# または、ワークスペース利用
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
```

### 3. 状態ロック

```hcl
# DynamoDBテーブル作成（AWSの場合）
resource "aws_dynamodb_table" "terraform_lock" {
  name           = "terraform-state-lock-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = var.environment
  }
}
```

## バージョン管理

```hcl
# versions.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

## 変数と環境管理

### 1. 変数定義

```hcl
# variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
```

### 2. tfvarsファイル

```hcl
# environments/prod/terraform.tfvars
environment = "prod"
aws_region  = "ap-northeast-1"

instance_count     = 3
instance_type      = "t3.large"
enable_monitoring  = true

tags = {
  Project     = "MyApp"
  ManagedBy   = "Terraform"
  CostCenter  = "Engineering"
}
```

### 3. ローカル変数

```hcl
# locals.tf
locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Timestamp   = timestamp()
    }
  )

  # 環境別設定
  instance_type = {
    dev     = "t3.micro"
    staging = "t3.small"
    prod    = "t3.large"
  }

  current_instance_type = local.instance_type[var.environment]
}
```

## セキュリティベストプラクティス

### 1. シークレット管理

```hcl
# ❌ BAD - ハードコード禁止
resource "aws_db_instance" "bad" {
  password = "hardcoded-password"  # 絶対にNG
}

# ✅ GOOD - Secrets Manager使用
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

resource "aws_db_instance" "good" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}

# ✅ GOOD - 環境変数使用
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
```

### 2. センシティブデータのマスキング

```hcl
variable "api_key" {
  description = "API key for external service"
  type        = string
  sensitive   = true
}

output "connection_string" {
  description = "Database connection string"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}
```

### 3. IAMポリシー（最小権限の原則）

```hcl
resource "aws_iam_role_policy" "app" {
  name = "${var.environment}-app-policy"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.app.arn}/*"
      }
    ]
  })
}
```

## リソース命名規則

```hcl
# 命名パターン: {environment}-{service}-{resource-type}-{index}
resource "aws_instance" "web" {
  count = var.instance_count

  tags = {
    Name = "${var.environment}-web-server-${count.index + 1}"
  }
}

# 例: prod-web-server-1, prod-web-server-2, prod-web-server-3
```

## データソース活用

```hcl
# 既存リソースの参照
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_vpc" "existing" {
  id = var.vpc_id
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = data.aws_vpc.existing.subnet_ids[0]
}
```

## 条件分岐とループ

### 1. count

```hcl
resource "aws_instance" "web" {
  count = var.create_instances ? var.instance_count : 0

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
}
```

### 2. for_each

```hcl
variable "users" {
  type = map(object({
    role = string
  }))
  default = {
    "alice" = { role = "admin" }
    "bob"   = { role = "developer" }
  }
}

resource "aws_iam_user" "users" {
  for_each = var.users

  name = each.key
  tags = {
    Role = each.value.role
  }
}
```

### 3. dynamic blocks

```hcl
resource "aws_security_group" "app" {
  name   = "${var.environment}-app-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

## CI/CD統合

### 1. GitHub Actions例

```yaml
# .github/workflows/terraform.yml
name: Terraform CI/CD

on:
  pull_request:
    paths:
      - 'terraform/**'
  push:
    branches:
      - main

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init
        working-directory: ./environments/prod

      - name: Terraform Validate
        run: terraform validate
        working-directory: ./environments/prod

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: ./environments/prod

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
        working-directory: ./environments/prod
```

### 2. Pre-commit hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint
```

## 実装チェックリスト

### 設計フェーズ
- [ ] 環境分離戦略を決定（ディレクトリ or ワークスペース）
- [ ] モジュール境界を定義
- [ ] 命名規則を策定
- [ ] タグ戦略を決定

### 実装フェーズ
- [ ] リモートバックエンド設定
- [ ] プロバイダーバージョン固定
- [ ] 変数バリデーション追加
- [ ] センシティブ変数をマーク
- [ ] モジュールREADME作成
- [ ] データソースで既存リソース参照

### セキュリティ
- [ ] シークレットをハードコードしない
- [ ] 最小権限のIAMポリシー
- [ ] 状態ファイルの暗号化
- [ ] .gitignoreで機密ファイル除外

### テスト・デプロイ
- [ ] `terraform fmt`で整形
- [ ] `terraform validate`で検証
- [ ] `terraform plan`で変更確認
- [ ] ドリフト検出の自動化
- [ ] CI/CDパイプライン構築

## ベストプラクティス

### DO ✅
- モジュールを小さく保つ（単一責任）
- リモートバックエンドを使用
- 状態ファイルをバージョン管理から除外
- .terraform.lock.hclをコミット
- タグを一貫して適用
- ドキュメントを最新に保つ
- terraform fmtを実行

### DON'T ❌
- 巨大なモジュールを作らない
- ハードコードされたシークレット
- 状態ファイルをgitにコミット
- プロバイダーバージョンを固定しない
- 本番環境で`terraform destroy`を気軽に実行
- 環境間でコードを重複させる

## トラブルシューティング

```bash
# 状態ファイルの確認
terraform show

# 状態ファイルのリスト
terraform state list

# 特定リソースの詳細
terraform state show aws_instance.web[0]

# リソースのインポート
terraform import aws_instance.web i-1234567890abcdef0

# 状態の更新（ドリフト修正）
terraform refresh

# ドリフト検出
terraform plan -detailed-exitcode
```

## コスト最適化

```hcl
# タグによるコスト配分
locals {
  cost_tags = {
    CostCenter  = var.cost_center
    Project     = var.project_name
    Environment = var.environment
  }
}

# リソースの自動停止（非本番環境）
resource "aws_instance" "app" {
  # ... 他の設定 ...

  # 本番以外は夜間停止
  count = var.environment == "prod" ? var.instance_count : 0

  tags = merge(
    local.cost_tags,
    {
      AutoShutdown = var.environment != "prod" ? "true" : "false"
    }
  )
}
```

## まとめ

このスキルは以下を保証します:

- 🏗️ **モジュール化**: 再利用可能で保守しやすいコード
- 🔒 **セキュリティ**: シークレット管理と最小権限
- 📊 **状態管理**: 安全なリモートバックエンドとロック
- 🚀 **CI/CD**: 自動化されたデプロイメント
- 💰 **コスト最適化**: タグ付けとリソース管理
- 📚 **ドキュメント**: 明確なモジュール説明
