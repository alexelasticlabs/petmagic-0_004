# PetMagic Admin Panel — Support System Redesign

## Objective

Redesign the current support module in the admin panel to achieve:

* a professional and scalable support workflow;
* clear operator interaction logic;
* predictable ticket lifecycle behavior;
* modern and clean UI/UX;
* proper responsiveness for different screen sizes;
* reduced operator cognitive load;
* improved ticket processing speed;
* centralized access to user, payment, and generation context.

The current implementation visually and functionally resembles a technical prototype rather than a production-grade support environment.

The redesign should transform the module into a structured support workspace comparable in usability and clarity to modern systems such as Intercom, Stripe Dashboard, Linear, GitHub Issues, or Zendesk.

---

# 1. Current Problems

## 1.1 Layout and Responsiveness Problems

Current layout behavior is unstable on large monitors and wide screens:

* the chat area stretches excessively;
* content loses visual hierarchy;
* large unused empty areas appear;
* side panels visually disconnect from the main content;
* some elements overflow containers;
* tabs and controls collide with each other;
* there is no consistent max-width strategy.

The interface currently scales proportionally instead of adaptively.

---

## 1.2 Unclear Ticket Lifecycle

Current ticket states and transitions are not understandable for operators.

Problems:

* unclear difference between “Open”, “Resolved”, and “Closed”;
* unclear ownership state;
* no explicit waiting logic;
* closing a ticket produces almost no visible workflow changes;
* the operator does not understand whether the ticket is still active;
* users can continue interacting with closed tickets without clear state transitions.

The system currently displays data but does not guide support workflow.

---

## 1.3 Poor Visual Hierarchy

The current interface lacks a unified design system.

Problems:

* inconsistent spacing;
* oversized empty areas;
* overloaded right panel;
* weak prioritization of important information;
* inconsistent buttons and badges;
* chat messages look visually unfinished;
* controls compete for attention;
* support queue resembles random cards instead of a structured workflow list.

The module currently feels visually fragmented and unpolished.

---

## 1.4 Inefficient Operator Workflow

Support operators must manually search for context across different sections of the admin panel.

Missing operational context:

* recent AI generations;
* failed generations;
* payment history;
* subscription status;
* token balance;
* recent errors;
* generation activity.

This increases response time and operator fatigue.

---

# 2. Proposed Ticket Lifecycle

The support system should use a simplified and predictable lifecycle.

## Ticket States

### New

Newly created ticket.

Characteristics:

* created by user;
* not assigned;
* awaiting first response.

---

### In Progress

Ticket is actively being processed.

Characteristics:

* assigned to operator;
* active communication;
* issue under investigation.

---

### Waiting For Customer

Support has responded and is waiting for user action.

Examples:

* waiting for confirmation;
* waiting for screenshot;
* waiting for retry result;
* waiting for additional information.

This state is critical for queue clarity.

---

### Closed

Issue resolved.

Characteristics:

* ticket archived;
* input disabled;
* read-only mode enabled;
* removed from active queue.

---

# 3. Automatic State Transitions

## Operator sends message

Transition:

* New → In Progress
* Waiting For Customer → In Progress

---

## User sends message

Transition:

* Waiting For Customer → In Progress
* Closed → In Progress (automatic reopen)

---

## Operator closes ticket

Transition:

* Any active state → Closed

Effects:

* reply field disabled;
* reply button removed;
* visible “Ticket Closed” state displayed;
* ticket removed from active queue.

---

# 4. Queue Redesign

The left column must become a professional support queue instead of a collection of profile cards.

## Queue Goals

Operators must immediately understand:

* who requires response;
* ticket priority;
* waiting duration;
* last activity;
* ownership;
* SLA urgency.

---

## Required Queue Information

Each queue row should contain:

* user name;
* user avatar;
* last message preview;
* current ticket state;
* assigned operator;
* waiting duration;
* SLA indicator;
* unread state;
* ticket priority.

---

## Queue Sorting Priority

Default sorting:

1. overdue tickets;
2. new tickets;
3. tickets waiting longest;
4. remaining active tickets.

---

## Required Filters

* All;
* New;
* In Progress;
* Waiting For Customer;
* Closed;
* Assigned To Me;
* Unassigned.

---

# 5. Layout Redesign

The current proportional layout should be replaced with a structured workspace layout.

## Recommended Desktop Layout

### Left Column

Support queue.

Fixed width:

320px

---

### Center Column

Chat workspace.

Flexible width:

1fr

---

### Right Column

Context and ticket details.

Fixed width:

380px

---

## Additional Requirements

* add max-width constraints for ultra-wide monitors;
* prevent excessive chat stretching;
* improve spacing consistency;
* preserve visual hierarchy on large screens;
* support adaptive collapsing behavior.

---

# 6. Right Panel Redesign

The current right panel is overloaded and lacks information hierarchy.

The redesign must separate information into structured blocks.

---

## Block 1 — Ticket Information

Contains:

* current state;
* priority;
* assigned operator;
* created date;
* last activity;
* SLA timer.

---

## Block 2 — User Information

Contains:

* avatar;
* name;
* email;
* registration date;
* account age;
* subscription plan.

---

## Block 3 — Product Context

Critical for fast support resolution.

Contains:

* token balance;
* recent purchases;
* recent AI generations;
* failed generations;
* latest generation errors;
* subscription information;
* payment status.

Operators must not navigate through multiple admin sections to gather context.

---

## Block 4 — Dangerous Actions

Separate visually isolated section.

Contains:

* block user;
* force logout;
* revoke subscription;
* refund actions;
* internal moderation actions.

---

# 7. Chat Redesign

The central workspace should resemble a modern professional messaging environment.

---

## Message Groups

Messages should be grouped by:

* Today;
* Yesterday;
* Earlier.

---

## Message Types

### User Messages

Left aligned.

---

### Support Messages

Right aligned.

---

### System Events

Neutral system cards.

Examples:

* ticket assigned;
* ticket reopened;
* subscription purchased;
* generation completed;
* payment failed;
* operator changed.

---

# 8. Attachment System Redesign

Current attachment handling is weak and disconnected from conversation flow.

## Required Improvements

* large preview support;
* image modal viewer;
* video preview support;
* direct download;
* navigation to related message;
* clear file metadata;
* drag-and-drop upload;
* upload progress state.

---

# 9. Closed Ticket Experience

Closed tickets must visually and functionally behave differently.

## Required Behavior

When ticket is closed:

* input field disabled;
* reply button hidden;
* read-only mode enabled;
* visible closed state banner displayed;
* main CTA becomes “Reopen Ticket”.

The operator must immediately understand that the conversation is archived.

---

# 10. Quick Replies System

Support workflows require reusable response templates.

## Required Features

* categorized templates;
* quick insertion;
* keyboard navigation;
* editable before send;
* multilingual support.

Example categories:

* payments;
* refunds;
* generation failures;
* subscription issues;
* moderation;
* onboarding.

---

# 11. SLA System

Current SLA display lacks operational clarity.

## Proposed SLA Indicators

### Green

Response time within target.

---

### Yellow

Approaching SLA limit.

---

### Red

SLA exceeded.

Requires immediate attention.

---

SLA state must be visible:

* in queue;
* inside ticket;
* in notification counters.

---

# 12. Visual Design Requirements

The support module should follow a unified design system.

## Design Direction

* clean enterprise UI;
* modern spacing system;
* compact but readable density;
* consistent component styling;
* visually calm interface;
* clear information hierarchy;
* modern typography;
* reduced visual noise.

---

## UI Goals

The interface should feel:

* professional;
* stable;
* operationally efficient;
* trustworthy;
* scalable.

The current visual prototype quality is insufficient for production usage.

---

# 13. Incremental Implementation Plan

To reduce risk and simplify testing, implementation should be split into independent releases.

---

## Release 1 — Ticket Lifecycle Foundation

Scope:

* new ticket states;
* automatic state transitions;
* SLA logic;
* closed ticket behavior;
* reopen logic.

---

## Release 2 — Queue Redesign

Scope:

* new queue layout;
* sorting;
* filtering;
* unread logic;
* SLA indicators.

---

## Release 3 — Chat Redesign

Scope:

* new message UI;
* attachment viewer;
* system events;
* upload improvements;
* closed ticket mode.

---

## Release 4 — Context Panel Redesign

Scope:

* user context;
* payment context;
* generation context;
* token information;
* moderation actions.

---

## Release 5 — UX and Visual Polish

Scope:

* responsiveness;
* animations;
* dark mode;
* accessibility;
* keyboard shortcuts;
* final visual refinement.

---

# Final Goal

The final result should not resemble a basic admin page.

The support module must become:

* a professional operator workspace;
* a scalable support environment;
* a context-driven support system;
* a fast operational dashboard for resolving user problems.

The redesign should significantly improve:

* support speed;
* operator clarity;
* maintainability;
* scalability;
* user communication quality;
* overall perceived product quality.
