# Terraform AWS - VPC
This setup consists of `main.tf` and `variables.tf`, designed to create a VPC with public and private subnets in the ap-northeast-2 region by default.
It is structured in a simple and intuitive way, making it easy for beginners (like me!) to understand and use.

## How to Use

**1. Provide the AWS CLI profile:**</br>
Ensure you specify your AWS CLI profile as a required variable.

**2. Initialize and Plan:**

```bash
terraform init
terraform plan
```

**3. Apply the Configuration:**</br>

```bash
terraform destroy
```

**4. Prevent Additional Costs:**</br>

After you're done, destroy the resources to avoid incurring unnecessary charges:

```bash
terraform destroy
```

## Features
### No Overlapping CIDR Blocks:
This script ensures there are no conflicts in CIDR blocks between the VPC and subnets.

### Unique Resource Naming:
Designed to minimize naming conflicts by generating unique Name tags for both the VPC and subnets.
 