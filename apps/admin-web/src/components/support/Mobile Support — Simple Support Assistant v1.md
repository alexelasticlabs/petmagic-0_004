# Mobile Support — Simple Support Assistant v1

## 1. Objective

At the current stage of the project, the mobile app does not need a complex AI-powered support bot. Instead, the first version should introduce a simple, predictable **Support Assistant v1**.

The purpose of this assistant is to help the user quickly identify the type of problem, receive a short basic recommendation, and create a support ticket only if needed.

The assistant should not replace human support. Its role is to improve the initial support entry point and provide the admin panel with more structured tickets.

---

# 2. Why a Complex Bot Is Not Needed Yet

For the MVP stage, a complex AI bot would add unnecessary product and technical complexity.

Potential issues:

- complex free-text interpretation logic;
- risk of incorrect or misleading answers;
- additional quality control requirements;
- increased backend and mobile implementation complexity;
- more difficult testing and debugging;
- harder moderation and support scenario management.

At this stage, the priority is to build a stable and understandable support flow:

```text
user selects a problem category
↓
receives a short recommendation
↓
if the issue is not resolved, creates a support ticket
↓
support operator receives a ticket with structured context
```

---

# 3. Role of Support Assistant v1

Support Assistant v1 should work as a simple guided flow.

Its responsibilities:

- help the user select the correct problem category;
- show a short relevant recommendation;
- offer to create a support ticket if the recommendation does not help;
- collect minimal required context;
- automatically attach related generation, payment, or subscription data when available;
- send a structured ticket to the support operator.

The assistant should not:

- conduct long conversations;
- analyze free-form text;
- make decisions instead of the support operator;
- automatically close tickets;
- issue refunds or compensate tokens;
- act as a fully autonomous AI agent.

---

# 4. Main User Flow

```text
User opens “Help & Support”
↓
User sees a list of common problem categories
↓
User selects a relevant topic
↓
Support Assistant shows a short recommendation
↓
User chooses one of two actions:
- “This helped”
- “Create support ticket”
↓
If the user selects “This helped” — no ticket is created
↓
If the user selects “Create support ticket” — the ticket form opens
↓
User adds description and optional attachments
↓
Ticket is created and appears in the admin panel
```

---

# 5. Interaction Principle

The Support Assistant must remain short, predictable, and non-intrusive.

Recommended limit:

```text
1 topic → 1 recommendation → 1 action choice
```

The user path should not exceed 2–3 steps before the option to contact support becomes available.

The assistant must not block access to human support behind a long scripted questionnaire.

---

# 6. Support Assistant v1 Topics

For MVP, the assistant should support a limited number of high-frequency scenarios.

---

## 6.1 Generation Issue

Used when the user has a problem with AI image or AI video generation.

Examples:

- generation did not start;
- generation failed;
- output quality is poor;
- pet is distorted;
- video does not look as expected.

Assistant message:

```text
For better results, please use a photo where the pet is clearly visible, not cropped, not blurry, and well lit.
```

Actions:

```text
[This helped]
[Create support ticket]
```

If the user creates a ticket, the system should suggest selecting a related generation or automatically attach it if the user opened support from a generation screen.

---

## 6.2 Generation Takes Too Long

Used when the user thinks the generation is stuck.

Assistant message:

```text
Video generation may take several minutes. It usually takes around 2–10 minutes. If it has taken too long, we can send this issue to support.
```

Actions:

```text
[Check later]
[Create support ticket]
```

If the ticket is created from an active generation, the related `generationId` should be attached automatically.

---

## 6.3 Tokens Did Not Arrive

Used when the user purchased tokens but does not see them in the balance.

Assistant message:

```text
Sometimes token delivery after payment may take a few minutes. If the tokens still do not appear, create a support ticket and we will check the purchase.
```

Actions:

```text
[Check later]
[Create support ticket]
```

If the user has a recent payment, it should be automatically attached to the ticket.

---

## 6.4 Premium Issue

Used when the user purchased Premium but the status is not active or is displayed incorrectly.

Assistant message:

```text
If Premium has already been paid for but is not visible in the app, please try restarting the app. If the problem remains, we will check your subscription status.
```

Actions:

```text
[This helped]
[Create support ticket]
```

If the user creates a ticket, the current subscription status should be attached when available.

---

## 6.5 Payment / Refund

Used for payment, billing, and refund-related questions.

Assistant message:

```text
We can check your payment or forward your refund request to support. Create a support ticket and we will attach the relevant purchase information if available.
```

Action:

```text
[Create support ticket]
```

The latest relevant payment should be attached to the ticket if available.

---

## 6.6 Other

Used for questions that do not match standard categories.

Assistant message:

```text
Please describe what happened. You can also attach a screenshot to help support understand the situation faster.
```

Action:

```text
[Create support ticket]
```

---

# 7. When a Ticket Is Created

A support ticket must not be created automatically when the user opens the assistant or selects a topic.

A ticket is created only after explicit user action:

```text
[Create support ticket]
```

This prevents the admin panel from being filled with empty, accidental, or incomplete support requests.

---

# 8. Ticket Creation Form

After selecting `Create support ticket`, the user should see a simple form.

## Form Fields

```text
Topic
Problem description
Related generation / payment / subscription
Attachments
Submit button
```

## Example

```text
Create support ticket

Topic:
Generation issue

Related generation:
Funny CEO Pet — Failed

Description:
[Describe what happened]

Attachments:
[Add screenshot]

[Send to support]
```

---

# 9. Automatic Context Attachment

Support Assistant should help pass useful context to the support operator.

---

## If the User Comes From a Generation

Attach:

```text
generationId
templateId
generationStatus
inputImageUrl
resultUrl, if available
errorCode, if available
createdAt
tokenCost
```

---

## If the Topic Is Payment-Related

Attach:

```text
paymentId
amount
currency
paymentStatus
purchasedProduct
createdAt
provider
```

---

## If the Topic Is Premium-Related

Attach:

```text
subscriptionId
subscriptionStatus
plan
renewalDate
provider
```

---

# 10. What the Support Operator Sees in the Admin Panel

The admin panel should clearly show that the ticket was created through the mobile assistant.

Example:

```text
Source: Mobile Support Assistant
Topic: Generation issue
Scenario: GenerationIssueBasic
Related generation: gen_123
```

A system event should also be added to the ticket history:

```text
User completed the “Generation issue” assistant flow and created a support ticket.
```

This helps the operator understand the initial context without asking unnecessary follow-up questions.

---

# 11. Message Sender Types

The support chat should support the following sender types:

```text
User
SupportAgent
Bot
System
```

---

## Bot

Used only for simple scripted assistant messages.

---

## System

Used for technical and workflow events.

Examples:

```text
Ticket created
Ticket reopened
Generation attached to ticket
Payment attached to ticket
Subscription attached to ticket
```

---

# 12. Out of Scope for MVP

The following features should not be included in the first version:

- LLM-based AI bot;
- free-text intent detection;
- automatic intent classification;
- long multi-step conversations;
- automatic refunds;
- automatic token compensation;
- automatic ticket closure by bot;
- AI-based photo quality analysis;
- complex personalization;
- autonomous bot decisions without operator review.

These features can be considered later after the basic support workflow becomes stable.

---

# 13. MVP Scope

## Required Features

1. `Help & Support` screen.
2. List of common problem categories.
3. Simple scripted Support Assistant.
4. Short recommendation for each topic.
5. `This helped` and `Create support ticket` actions.
6. Ticket creation form.
7. File attachment support.
8. Automatic linking of generation, payment, or subscription context.
9. Assistant source displayed in the admin panel.
10. System events in ticket history.

---

# 14. Recommended Mobile Flow

```text
Support Home
↓
Topic selection
↓
Support Assistant recommendation
↓
Did it help?
├── Yes → no ticket is created
└── No / Create support ticket
    ↓
    Ticket form
    ↓
    Submit
    ↓
    Support chat
```

---

# 15. Final Decision

For the current stage of the project, PetMagic should implement **Simple Support Assistant v1**.

This is not an AI bot. It is a scripted guided flow based on predefined support scenarios:

```text
topic selection → short recommendation → ticket creation if needed
```

This approach is easier to implement, easier to test, safer for MVP, and more predictable for users. It avoids unnecessary complexity while still improving the support experience and helping operators receive better structured tickets.
