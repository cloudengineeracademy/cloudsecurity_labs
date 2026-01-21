#!/bin/bash

# Cloud Security Assessment - Reconnaissance Script
# Gathers information about AWS resources in the account

echo ""
echo "=============================================="
echo "  RECONNAISSANCE - Cloud Security Assessment"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get account info
echo -e "${BLUE}[Account Information]${NC}"
echo ""
aws sts get-caller-identity --output table
echo ""

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# EC2 Instances
echo "----------------------------------------------"
echo -e "${BLUE}[EC2 Instances]${NC}"
echo "----------------------------------------------"
echo ""

EC2_COUNT=$(aws ec2 describe-instances --query 'length(Reservations[].Instances[])' --output text 2>/dev/null)
echo "Total instances: $EC2_COUNT"
echo ""

aws ec2 describe-instances \
    --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name,PublicIP:PublicIpAddress,Name:Tags[?Key==`Name`].Value|[0]}' \
    --output table 2>/dev/null

echo ""

# Security Groups
echo "----------------------------------------------"
echo -e "${BLUE}[Security Groups]${NC}"
echo "----------------------------------------------"
echo ""

SG_COUNT=$(aws ec2 describe-security-groups --query 'length(SecurityGroups)' --output text 2>/dev/null)
echo "Total security groups: $SG_COUNT"
echo ""

aws ec2 describe-security-groups \
    --query 'SecurityGroups[].{ID:GroupId,Name:GroupName,VPC:VpcId,Description:Description}' \
    --output table 2>/dev/null

echo ""

# S3 Buckets
echo "----------------------------------------------"
echo -e "${BLUE}[S3 Buckets]${NC}"
echo "----------------------------------------------"
echo ""

BUCKET_COUNT=$(aws s3 ls 2>/dev/null | wc -l)
echo "Total buckets: $BUCKET_COUNT"
echo ""

aws s3 ls 2>/dev/null

echo ""

# IAM Users
echo "----------------------------------------------"
echo -e "${BLUE}[IAM Users]${NC}"
echo "----------------------------------------------"
echo ""

USER_COUNT=$(aws iam list-users --query 'length(Users)' --output text 2>/dev/null)
echo "Total users: $USER_COUNT"
echo ""

aws iam list-users \
    --query 'Users[].{UserName:UserName,Created:CreateDate}' \
    --output table 2>/dev/null

echo ""

# IAM Roles
echo "----------------------------------------------"
echo -e "${BLUE}[IAM Roles]${NC}"
echo "----------------------------------------------"
echo ""

ROLE_COUNT=$(aws iam list-roles --query 'length(Roles)' --output text 2>/dev/null)
echo "Total roles: $ROLE_COUNT"
echo ""

aws iam list-roles \
    --query 'Roles[?!starts_with(RoleName, `AWS`)].{RoleName:RoleName,Created:CreateDate}' \
    --output table 2>/dev/null

echo ""

# Summary
echo "=============================================="
echo -e "${GREEN}  RECONNAISSANCE COMPLETE${NC}"
echo "=============================================="
echo ""
echo "Resources discovered:"
echo "  EC2 Instances:    $EC2_COUNT"
echo "  Security Groups:  $SG_COUNT"
echo "  S3 Buckets:       $BUCKET_COUNT"
echo "  IAM Users:        $USER_COUNT"
echo "  IAM Roles:        $ROLE_COUNT"
echo ""
echo "Next step: Run ./scripts/security-scan.sh"
echo ""
