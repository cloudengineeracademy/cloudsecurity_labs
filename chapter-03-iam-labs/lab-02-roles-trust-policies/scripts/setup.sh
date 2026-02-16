#!/bin/bash

# Lab 02: Roles & Trust Policies — Setup
# Creates group, user, and roles for the lab

echo ""
echo "=============================================="
echo "  Lab 02: Roles & Trust Policies — Setup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "  Account: $ACCOUNT_ID"
echo ""

# Check for existing resources
aws iam get-group --group-name iam-lab-dev-group >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}WARNING: Lab resources already exist.${NC}"
    echo "  Run cleanup first: bash lab-02-roles-trust-policies/scripts/cleanup.sh"
    exit 1
fi

# ============================================================
# Step 1: Create group
# ============================================================
echo -e "${BLUE}Step 1: Creating dev group...${NC}"
aws iam create-group --group-name iam-lab-dev-group >/dev/null 2>&1
aws iam attach-group-policy --group-name iam-lab-dev-group \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
echo -e "  ${GREEN}Created: iam-lab-dev-group (S3 read-only)${NC}"

# ============================================================
# Step 2: Create user in group
# ============================================================
echo -e "${BLUE}Step 2: Creating group user...${NC}"
aws iam create-user --user-name iam-lab-group-user >/dev/null 2>&1
aws iam add-user-to-group --group-name iam-lab-dev-group --user-name iam-lab-group-user
echo -e "  ${GREEN}Created: iam-lab-group-user (member of iam-lab-dev-group)${NC}"

# ============================================================
# Step 3: Create assumable role
# ============================================================
echo -e "${BLUE}Step 3: Creating assumable role...${NC}"
aws iam create-role --role-name iam-lab-assumable-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"AWS": "arn:aws:iam::'"$ACCOUNT_ID"':root"},
            "Action": "sts:AssumeRole"
        }]
    }' >/dev/null 2>&1

aws iam attach-role-policy --role-name iam-lab-assumable-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
echo -e "  ${GREEN}Created: iam-lab-assumable-role (S3 read-only, trusted by this account)${NC}"

# ============================================================
# Step 4: Create EC2 role
# ============================================================
echo -e "${BLUE}Step 4: Creating EC2 role...${NC}"
aws iam create-role --role-name iam-lab-ec2-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }' >/dev/null 2>&1

aws iam attach-role-policy --role-name iam-lab-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
echo -e "  ${GREEN}Created: iam-lab-ec2-role (S3 read-only, trusted by EC2 service)${NC}"

# ============================================================
# Step 5: Create cross-account role
# ============================================================
echo -e "${BLUE}Step 5: Creating cross-account role...${NC}"
aws iam create-role --role-name iam-lab-cross-account-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"AWS": "arn:aws:iam::123456789012:root"},
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "unique-external-id-here"
                }
            }
        }]
    }' >/dev/null 2>&1
echo -e "  ${GREEN}Created: iam-lab-cross-account-role (trusted by external account 123456789012)${NC}"

echo ""
echo "=============================================="
echo "  Setup Complete"
echo "=============================================="
echo ""
echo "  Resources created:"
echo "    - iam-lab-dev-group (S3 read-only)"
echo "    - iam-lab-group-user (member of dev group)"
echo "    - iam-lab-assumable-role (trust: this account)"
echo "    - iam-lab-ec2-role (trust: EC2 service)"
echo "    - iam-lab-cross-account-role (trust: external account)"
echo ""
echo "  Next step: Follow the README or run:"
echo "    bash lab-02-roles-trust-policies/scripts/assume-role-demo.sh"
echo ""
