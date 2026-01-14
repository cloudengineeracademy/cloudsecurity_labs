# Lab 03: CIA Triad with S3

## Overview

The CIA Triad isn't just theory - it's the foundation of every security decision. In this lab, you'll implement each principle hands-on using Amazon S3.

| Principle           | Meaning                             | Threat                     |
| ------------------- | ----------------------------------- | -------------------------- |
| **Confidentiality** | Only authorized people can see data | Unauthorized access        |
| **Integrity**       | Data hasn't been tampered with      | Data modification/deletion |
| **Availability**    | Data is accessible when needed      | Data loss, service outage  |

## Cost

**FREE** - Uses S3 Free Tier (5GB storage, 20,000 GET, 2,000 PUT requests/month)

## Learning Objectives

By the end of this lab, you will:

1. Create and configure an S3 bucket
2. Implement confidentiality controls (access blocking, encryption)
3. Implement integrity protection (versioning)
4. Understand availability mechanisms (built-in replication)

---

## Part 1: Create Your Lab Bucket

### Step 1.1: Set Your Bucket Name

S3 bucket names must be globally unique. Run this to set your bucket name:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="cia-lab-${ACCOUNT_ID}"
echo "Your bucket name: $BUCKET_NAME"
```

> **Important**: If you close your terminal, run this command again to reset `BUCKET_NAME`.

### Step 1.2: Create the Bucket

```bash
aws s3 mb s3://${BUCKET_NAME}
aws s3 ls | grep cia-lab
```

---

## Part 2: Confidentiality

**Goal**: Only authorized users should access data.

### Step 2.1: Upload a Test File

```bash
echo "CONFIDENTIAL: Employee SSN 123-45-6789" > /tmp/secret.txt
aws s3 cp /tmp/secret.txt s3://${BUCKET_NAME}/secret.txt
```

### Step 2.2: Test Public Access

Try to access the file via a public URL (as if you were an attacker):

```bash
REGION=$(aws s3api get-bucket-location --bucket ${BUCKET_NAME} --query 'LocationConstraint' --output text)
[ "$REGION" = "None" ] || [ "$REGION" = "null" ] && REGION="us-east-1"

URL="https://${BUCKET_NAME}.s3.${REGION}.amazonaws.com/secret.txt"
echo "Testing: $URL"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
echo "Response: $HTTP_CODE"

if [ "$HTTP_CODE" = "403" ]; then
  echo "GOOD - Access denied (confidentiality protected)"
else
  echo "WARNING - Unexpected response"
fi
```

**Expected**: `403` (Forbidden). S3 buckets are private by default.

### Step 2.3: Enable Bucket-Level Public Access Block

Defence in depth - add bucket-level protection even if account-level exists:

```bash
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Step 2.4: Enable Encryption

Encrypt data at rest:

```bash
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
      "BucketKeyEnabled": true
    }]
  }'

# Verify
aws s3api get-bucket-encryption --bucket ${BUCKET_NAME}
```

### Confidentiality Summary

| Control             | Purpose                             |
| ------------------- | ----------------------------------- |
| Public Access Block | Prevents accidental public exposure |
| No Bucket Policy    | No public access granted            |
| AES-256 Encryption  | Data unreadable without keys        |

---

## Part 3: Integrity

**Goal**: Data should not be tampered with or changed unexpectedly.

### Step 3.1: Enable Versioning

```bash
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# Verify
aws s3api get-bucket-versioning --bucket ${BUCKET_NAME}
```

### Step 3.2: Create Multiple Versions

Upload three versions of the same file. Watch S3 track each one:

```bash
# Upload Version 1 - the ORIGINAL
echo "ORIGINAL SECRET: The password is 'correct-horse-battery-staple'" > /tmp/test-integrity.txt
aws s3 cp /tmp/test-integrity.txt s3://${BUCKET_NAME}/test-integrity.txt
echo "Uploaded: ORIGINAL"
```

```bash
# Upload Version 2 - MODIFIED by mistake
echo "MODIFIED: The password is 'oops-i-changed-it'" > /tmp/test-integrity.txt
aws s3 cp /tmp/test-integrity.txt s3://${BUCKET_NAME}/test-integrity.txt
echo "Uploaded: MODIFIED"
```

```bash
# Upload Version 3 - CORRUPTED by attacker
echo "CORRUPTED: The password is 'hacked-by-attacker'" > /tmp/test-integrity.txt
aws s3 cp /tmp/test-integrity.txt s3://${BUCKET_NAME}/test-integrity.txt
echo "Uploaded: CORRUPTED"
```

### Step 3.3: See What's Currently in the File

```bash
aws s3 cp s3://${BUCKET_NAME}/test-integrity.txt -
```

You'll see the CORRUPTED version (the attacker's data). Not good!

### Step 3.4: View All Versions

```bash
aws s3api list-object-versions \
  --bucket ${BUCKET_NAME} \
  --prefix test-integrity.txt \
  --query 'Versions[].{VersionId:VersionId,LastModified:LastModified,IsLatest:IsLatest}' \
  --output table
```

You'll see 3 versions. The **oldest** (bottom of list) is your ORIGINAL.

### Step 3.5: Look at Each Version's Content

Let's see what's in each version:

```bash
echo "=== Showing all 3 versions ==="
for VERSION in $(aws s3api list-object-versions --bucket ${BUCKET_NAME} --prefix test-integrity.txt --query 'Versions[].VersionId' --output text); do
  echo ""
  echo "Version: $VERSION"
  aws s3api get-object --bucket ${BUCKET_NAME} --key test-integrity.txt --version-id $VERSION /tmp/v.txt >/dev/null 2>&1
  cat /tmp/v.txt
done
```

Now you can see exactly what's in each version.

### Step 3.6: Recover the Original Version

The ORIGINAL is the **oldest** version (last in the list). Let's restore it:

```bash
# Get the OLDEST version (the original)
ORIGINAL_VERSION=$(aws s3api list-object-versions \
  --bucket ${BUCKET_NAME} \
  --prefix test-integrity.txt \
  --query 'Versions[-1].VersionId' \
  --output text)

echo "Original version ID: $ORIGINAL_VERSION"

# Download it
aws s3api get-object \
  --bucket ${BUCKET_NAME} \
  --key test-integrity.txt \
  --version-id ${ORIGINAL_VERSION} \
  /tmp/recovered.txt

echo ""
echo "=== RECOVERED CONTENT ==="
cat /tmp/recovered.txt
```

**Result**: You recovered the original data with the correct password, even after it was modified and corrupted.

### Step 3.7: Test Delete Protection

With versioning, deletes don't actually remove data:

```bash
# "Delete" the file
aws s3 rm s3://${BUCKET_NAME}/test-integrity.txt
```

Try to access it:

```bash
aws s3 cp s3://${BUCKET_NAME}/test-integrity.txt /tmp/check.txt 2>&1 || echo "File appears deleted!"
```

The file seems gone. But let's check what S3 actually did:

```bash
# Show BOTH versions AND delete markers
echo "=== Versions (your data is still here) ==="
aws s3api list-object-versions \
  --bucket ${BUCKET_NAME} \
  --prefix test-integrity.txt \
  --query 'Versions[].VersionId'

echo ""
echo "=== Delete Markers (this is what 'hides' the file) ==="
aws s3api list-object-versions \
  --bucket ${BUCKET_NAME} \
  --prefix test-integrity.txt \
  --query 'DeleteMarkers[].VersionId'
```

The delete just added a "delete marker" - your 3 versions are still there!

### Step 3.8: Restore Deleted Data

Remove the delete marker to "undelete" the file:

```bash
# Get the delete marker ID
DELETE_MARKER=$(aws s3api list-object-versions \
  --bucket ${BUCKET_NAME} \
  --prefix test-integrity.txt \
  --query 'DeleteMarkers[0].VersionId' \
  --output text)

echo "Removing delete marker: $DELETE_MARKER"

# Delete the delete marker (yes, delete the delete!)
aws s3api delete-object \
  --bucket ${BUCKET_NAME} \
  --key test-integrity.txt \
  --version-id ${DELETE_MARKER}
```

Now check - the file is back:

```bash
echo "=== File restored! ==="
aws s3 cp s3://${BUCKET_NAME}/test-integrity.txt -
```

### Integrity Summary

| Control          | Purpose                                   |
| ---------------- | ----------------------------------------- |
| Versioning       | Track all changes, recover from tampering |
| Delete Markers   | Prevent accidental permanent deletion     |
| Version Recovery | Restore to any previous state             |

---

## Part 4: Availability

**Goal**: Data should be accessible when needed.

### Step 4.1: Understand S3's Built-in Availability

S3 provides **99.999999999% (11 9's) durability** automatically:

- Data is replicated across multiple Availability Zones
- No configuration required - this is built-in

```bash
aws s3api get-bucket-location --bucket ${BUCKET_NAME}
```

### Step 4.2: Test Data Retrieval

```bash
time aws s3 cp s3://${BUCKET_NAME}/secret.txt /tmp/download-test.txt
cat /tmp/download-test.txt
```

### Step 4.3: Storage Classes (Know These)

| Class               | Access Time      | Use Case                |
| ------------------- | ---------------- | ----------------------- |
| STANDARD            | Immediate        | Frequently accessed     |
| INTELLIGENT_TIERING | Immediate        | Unknown access patterns |
| GLACIER             | Minutes to hours | Archives, compliance    |

For this lab, we use STANDARD (default).

### Availability Summary

| Feature              | Status    |
| -------------------- | --------- |
| Multi-AZ Replication | Automatic |
| 11 9's Durability    | Built-in  |
| Storage Class        | STANDARD  |

---

## Part 5: Cleanup

**Important**: Delete the bucket to avoid any charges.

### Option 1: Use the Cleanup Script (Recommended)

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

### Option 2: Manual Cleanup

Because versioning is enabled, you need to delete all versions first:

```bash
# Step 1: Delete all object versions
echo "Deleting object versions..."
aws s3api list-object-versions --bucket ${BUCKET_NAME} --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text | while read key version; do
  [ -n "$key" ] && aws s3api delete-object --bucket ${BUCKET_NAME} --key "$key" --version-id "$version"
done

# Step 2: Delete all delete markers
echo "Deleting delete markers..."
aws s3api list-object-versions --bucket ${BUCKET_NAME} --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text | while read key version; do
  [ -n "$key" ] && aws s3api delete-object --bucket ${BUCKET_NAME} --key "$key" --version-id "$version"
done

# Step 3: Delete the bucket
echo "Deleting bucket..."
aws s3 rb s3://${BUCKET_NAME}
echo "Done!"
```

---

## Summary

| Principle           | Threat              | Control Implemented                |
| ------------------- | ------------------- | ---------------------------------- |
| **Confidentiality** | Unauthorized access | Block Public Access + Encryption   |
| **Integrity**       | Data tampering      | Versioning + Delete protection     |
| **Availability**    | Data loss           | S3's built-in multi-AZ replication |

---

## Key Takeaways

1. **Confidentiality by default** - S3 is private by default. Don't change this without good reason.
2. **Encryption is one command** - No excuse not to enable it.
3. **Versioning is your safety net** - Protects against both accidents and attacks.
4. **S3 durability is exceptional** - 11 9's means you almost certainly won't lose data.

---

## Reflection Questions

1. If an attacker got read access to your bucket, which CIA property is broken?
2. If ransomware encrypted all your files, which CIA properties are affected?
3. Why does versioning help with both integrity AND availability?

---

## Next Lab

Continue to [Lab 04: Defence Layers Audit](../lab-04-defence-layers-audit/)
