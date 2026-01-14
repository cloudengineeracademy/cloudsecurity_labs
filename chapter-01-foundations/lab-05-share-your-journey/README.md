# Lab 05: Share Your Journey

## Overview

You've completed Chapter 1. You've deployed infrastructure, found vulnerabilities, and learned to think like a security engineer.

Now it's time to share what you've learned.

**Why share?**
- Teaching reinforces your own learning
- Builds your professional brand
- Shows proof of work to employers
- Connects you with the security community
- Helps others on the same journey

---

## The Assignment

Create a LinkedIn article (not just a post) documenting your Chapter 1 journey.

### What to Include

**1. Your Starting Point**
- What was your background before this?
- Why are you learning cloud security?
- What did you expect vs what you found?

**2. What You Built**
- Screenshot of your CloudFormation stack
- Screenshot of the vulnerability scan output
- Screenshot of the defence audit results
- Diagrams explaining the concepts (see below)

**3. Key Concepts You Learned**

Pick 3-5 concepts and explain them in your own words:

- CIA Triad (Confidentiality, Integrity, Availability)
- Defence in Depth / 6 Layers
- Attack Surface
- IMDSv1 vs IMDSv2 (and the Capital One breach)
- Why MFA matters
- Security Groups as virtual firewalls
- S3 encryption and public access blocks

**4. A Real Finding**

Share one specific vulnerability you found and explain:
- What the misconfiguration was
- Why it's dangerous
- How to fix it
- Real-world impact (breaches, etc.)

**5. What's Next**

What are you learning next? What's your goal?

---

## Create Your Own Diagrams

Diagrams make complex concepts simple. They show you truly understand the material - not just copying commands.

**Tools to create diagrams (all free):**
- [Excalidraw](https://excalidraw.com) - Hand-drawn style, great for quick diagrams
- [draw.io](https://draw.io) - Professional diagrams, AWS icons included
- [Miro](https://miro.com) - Collaborative whiteboard
- [Canva](https://canva.com) - Templates and easy design

**Diagrams to create:**

### 1. Defence in Depth Layers
Show the 6 layers as concentric circles or stacked boxes:
```
┌─────────────────────────────────────┐
│           PERIMETER                 │
│  ┌───────────────────────────────┐  │
│  │         NETWORK               │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │       IDENTITY          │  │  │
│  │  │  ┌───────────────────┐  │  │  │
│  │  │  │     COMPUTE       │  │  │  │
│  │  │  │  ┌─────────────┐  │  │  │  │
│  │  │  │  │    DATA     │  │  │  │  │
│  │  │  │  └─────────────┘  │  │  │  │
│  │  │  └───────────────────┘  │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
         + DETECTION (monitoring all layers)
```

### 2. IMDSv1 vs IMDSv2 Attack Flow
Show how an attacker exploits IMDSv1:
```
┌──────────────┐    SSRF Attack    ┌──────────────┐
│   Attacker   │ ─────────────────→│  Web Server  │
└──────────────┘                   └──────┬───────┘
                                          │
                    curl 169.254.169.254  │
                                          ▼
                                   ┌──────────────┐
                                   │    IMDS      │
                                   │  (Metadata)  │
                                   └──────┬───────┘
                                          │
                        IAM Credentials   │
                                          ▼
                                   ┌──────────────┐
                                   │  S3 Buckets  │
                                   │  (Customer   │
                                   │    Data)     │
                                   └──────────────┘

IMDSv2 BLOCKS this by requiring a session token first
```

### 3. CIA Triad
Simple triangle with examples:
```
                    CONFIDENTIALITY
                    (Who can see it?)
                         /\
                        /  \
                       /    \
            Encryption/      \Access Controls
                     /        \
                    /          \
                   /____________\
        INTEGRITY               AVAILABILITY
     (Who can change it?)    (Can we access it?)
         Versioning              Backups
         MFA Delete              Replication
```

### 4. Security Group Flow
Show traffic filtering:
```
    Internet
        │
        ▼
┌───────────────────┐
│   Security Group  │◄── Inbound Rules
│   ┌───────────┐   │    - Port 22 from MY_IP only
│   │    EC2    │   │    - Port 443 from anywhere
│   │  Instance │   │
│   └───────────┘   │
│                   │◄── Outbound Rules
└───────────────────┘    - All traffic allowed
```

**Pro tip:** Create your diagrams, screenshot them, and include in your article. This shows you can communicate complex ideas visually - a skill employers value.

---

## Article Template

Use this structure:

```
Title: "I Started Learning Cloud Security - Here's What I Discovered"

[Opening Hook]
- Why you started this journey
- What surprised you most

[What I Built]
- Brief overview of the labs
- Include 2-3 screenshots
- Include 1-2 diagrams you created

[Key Concept Deep Dive]
- Pick ONE concept and explain it well
- Example: IMDSv1 and how it caused the Capital One breach
- Use a diagram to illustrate

[My Findings]
- Share a vulnerability you found
- Explain why it matters

[What's Next]
- Your learning path
- Call to action for others

[Tags and Mentions]
```

---

## Screenshots to Include

Take screenshots of:

1. **CloudFormation Stack** - AWS Console showing your deployed resources
2. **Vulnerability Scan** - Terminal output showing findings
3. **Security Group Rules** - Console showing open ports
4. **S3 Bucket Settings** - Encryption and public access configuration
5. **Defence Audit Results** - Your security score
6. **Your Diagrams** - The visuals you created

**Pro tip:** Blur or crop out your AWS Account ID in screenshots.

---

## How to Create a LinkedIn Article

1. Go to LinkedIn
2. Click "Write article" (not "Start a post")
3. Add a cover image (your Defence in Depth diagram or terminal screenshot)
4. Write your article using the template above
5. Add relevant images and diagrams throughout
6. Preview before publishing

---

## Tagging

When you publish, tag:

- **Soleyman Shahir** - [linkedin.com/in/soleymanshahir](https://linkedin.com/in/soleymanshahir)
- **Cloud Engineer Academy** - @cloudengineeracademy

Use these hashtags:
```
#CloudSecurity #AWS #CyberSecurity #LearningInPublic #CloudEngineerAcademy
```

---

## Examples of Good Posts

**Strong opening hooks:**
- "I just found 5 security vulnerabilities in my own AWS account..."
- "The Capital One breach could have been prevented with one setting change..."
- "I deployed intentionally vulnerable infrastructure to learn how attackers think..."

**What makes it engaging:**
- Specific examples, not vague statements
- Screenshots showing real output
- Your own diagrams explaining concepts
- Explaining the "why" not just the "what"
- Admitting what you didn't know before
- Actionable takeaways for readers

---

## Checklist Before Publishing

- [ ] Article (not just a post) with cover image
- [ ] At least 2-3 screenshots included
- [ ] At least 1 diagram you created yourself
- [ ] Explained concepts in your own words
- [ ] Shared a specific finding with context
- [ ] Tagged Soleyman Shahir and Cloud Engineer Academy
- [ ] Used relevant hashtags
- [ ] Proofread for typos

---

## Want to Do More? Create a Post Series

One article is great. But a **series of posts** builds momentum and keeps you visible.

See **[linkedin-post-series.md](./linkedin-post-series.md)** for a complete 7-day content strategy:

- Day 1: The Hook - Announce your journey
- Day 2: IMDSv1 Deep Dive
- Day 3: Security Groups
- Day 4: CIA Triad and S3
- Day 5: Defence in Depth
- Day 6: Your Audit Results
- Day 7: Wrap-Up and Reflection

Each post builds on the last. By the end of the week, you'll have 7 pieces of content proving your cloud security knowledge.

---

## Why This Matters

Every article you write:
- Proves you're actively learning
- Shows you can explain technical concepts
- Demonstrates visual communication skills
- Builds your network in the industry
- Creates content that lives forever on your profile
- Differentiates you from other candidates

Employers search LinkedIn. When they find your article explaining IMDSv1 vulnerabilities with diagrams you created and screenshots of your actual work - that's proof you know your stuff.

---

## Submit Your Article

Once published:

1. Copy the article URL
2. Share it in the course community
3. Engage with comments on your post
4. Connect with others who comment

---

## What's Next

Congratulations - you've completed Chapter 1!

You now have:
- Hands-on AWS security experience
- A published article proving your knowledge
- Diagrams showing you understand the concepts
- A growing professional network

Continue to **Chapter 2: IAM Deep Dive** to go deeper into identity and access management.
