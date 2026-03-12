# Programmer Obligations and Prohibited Conduct

**Vendor / Programmer Agreement — TheMarketRobo SDK**

---

## 1. Title and Parties

This document ("**Programmer Obligations**") sets out the obligations and prohibited conduct applicable to any person or entity ("**Programmer**" or "**Vendor**") who uses the TheMarketRobo Software Development Kit ("**SDK**") and/or distributes any product built with or incorporating the SDK via The Market Robo platform. The SDK and platform are owned and operated by **TMKR GLOBAL, LLC** ("**Company**" or "**we**").

By using the SDK and/or distributing a Product (as defined below) via the Platform, the Programmer agrees to be bound by this document.

---

## 2. Definitions

- **Product** means any Expert Advisor (EA), Custom Indicator, or other MQL5 program that is built with, incorporates, or is distributed in connection with the SDK, including any version thereof distributed to end users ("**Customers**").
- **Platform** means The Market Robo, the trading tools marketplace and associated services operated by the Company, including the official website **https://www.themarketrobo.com/** and the TheMarketRobo API and Vendor Portal.
- **SDK** means the TheMarketRobo MQL5 Software Development Kit and all related header files, source code, documentation, and materials provided by the Company.
- **Customer** means any end user who obtains, uses, or accesses a Product (whether through the Platform or otherwise in connection with the Platform).

---

## 3. Ownership and Product Identification

3.1 The Product **must at all times** identify **TMKR GLOBAL, LLC** and **The Market Robo** platform as the owner and operator of the product and the platform through which it is licensed and managed.

3.2 The **only** permitted official URL for customer-facing identification of the product and platform is:

**https://www.themarketrobo.com/**

3.3 Any reference to the product, its origin, or where Customers may obtain support or further information must direct to the Platform and the above URL, and must not direct to the Programmer's own website, social media, or any third party.

---

## 4. Prohibited Acts

The Programmer **must not** engage in any of the following acts. The following list is intended to be comprehensive but not exhaustive; the Company may treat conduct that has the same effect as a breach of these obligations even if not explicitly listed.

### 4.1 Redirects and Off-Platform Links

The Programmer must not include in the Product (including in its user interface, alerts, comments, labels, or any other output) any name, link, URL, web address, or other reference that directs or redirects the Customer to the Programmer's own website, social media profile, messaging channel (e.g. Telegram, Discord), or to any third party. The Product must not facilitate or encourage Customers to contact the Programmer or any third party directly for support, licensing, or information in a way that bypasses the Platform.

### 4.2 Product Identification and Rebranding

The Programmer must not present the Product as owned, operated, or licensed by anyone other than the Company or the Platform. The Programmer must not rebrand, white-label, or otherwise represent the Product in a manner that obscures or diminishes the identification of TMKR GLOBAL, LLC and The Market Robo as the owner and operator of the product and platform.

### 4.3 Time- or Condition-Based Third-Party Promotion

The Programmer must not implement any function, routine, or behaviour in the Product that triggers after a certain time, number of runs, or other condition (including but not limited to use of MQL5 functions such as `Alert()`, `Comment()`, `MessageBox()`, `SendNotification()`, or any mechanism that opens a URL or executable) where the purpose or effect is to introduce, promote, or refer the Customer to the Programmer, another developer, or any third party. This prohibition includes "time bomb" or delayed messages that appear after a date or condition and that direct users away from the Platform or toward the Programmer or a third party.

### 4.4 Removing or Altering Branding

The Programmer must not remove, hide, obscure, or alter any copyright, ownership, or branding notices contained in the SDK or required by the Company, including but not limited to `#property copyright`, `#property link`, and any visible or embedded identification of the Company or the Platform in the distributed Product.

### 4.5 Opening External URLs or Executables

The Programmer must not use `ShellExecuteW`, any other DLL-based or native mechanism to open a web browser or external executable, or any other means that directs the Customer to a URL or application other than the sole permitted URL **https://www.themarketrobo.com/** (and only where necessary for legitimate product identification). The Product must not launch browsers or executables that direct users to the Programmer's or any third party's site or service.

### 4.6 Unauthorised Network Usage

The Programmer must not use `WebRequest()` or any equivalent or alternative HTTP or network mechanism in the Product to communicate with domains or endpoints other than those sanctioned by the Company for TheMarketRobo API use (e.g. the official API base URLs), except where explicitly permitted in writing by the Company.

### 4.7 Bypassing Platform Control

The Programmer must not distribute a version of the Product that has the SDK disabled (e.g. by undefining `SDK_ENABLED` or otherwise removing or bypassing SDK functionality) for the purpose of distributing the Product as a product under the Platform's name or in connection with the Platform, so that it operates without the Platform's session, heartbeat, licensing, or control. This prohibition does not prevent the Programmer from building a separate, standalone product that is not distributed via or in connection with the Platform, in accordance with the Company's policies.

### 4.8 Modifying SDK Source

The Programmer must not alter the SDK source code (including but not limited to `CSDKConstants.mqh`, `SDK_API_BASE_URL`, or any file in the SDK package) to redirect traffic, change platform or Company identity, circumvent authentication or licensing checks, or otherwise undermine the Platform's control or the Company's ownership.

### 4.9 Chart and User Interface Branding

The Programmer must not use `Comment()`, `ObjectCreate()` (including text or label objects), or any other chart or user-interface element to display the Programmer's name, URL, or the name or URL of any third party in preference to or in place of the Company and the Platform. Any visible branding on the chart or in the Product's UI must identify the product as The Market Robo / TMKR GLOBAL, LLC with the sole permitted URL **https://www.themarketrobo.com/**.

### 4.10 Time Bombs and Expiry Abuse

The Programmer must not include code that, after a specified date or condition, degrades the Product's functionality, displays messages that direct users to the Programmer or a third party (e.g. "contact vendor directly", "trial expired" with an external link), or redirects or encourages the Customer to use channels outside the Platform.

### 4.11 Reverse Engineering and Stripping Protection

The Programmer must not decompile, disassemble, or otherwise reverse engineer the SDK or the Company's protection mechanisms, and must not remove or bypass license, session, or authentication checks in order to enable unlicensed use or to redirect Customers to the Programmer or any third party.

---

## 5. Acceptance and Acknowledgment

By using the SDK and/or distributing a Product via or in connection with the Platform, the Programmer:

(a) acknowledges that they have read and understood this document;  
(b) agrees to comply with all provisions of this document;  
(c) promises not to engage in any of the prohibited acts set out in Section 4 or any conduct having the same effect; and  
(d) agrees that breach of these obligations may result in removal from the Platform, termination of any vendor or programmer agreement, and legal action as set out below.

---

## 6. Consequences of Breach

The Company reserves the right to take all available remedies in respect of any breach of this document, including but not limited to:

- suspension or termination of the Programmer's access to the Platform, Vendor Portal, and SDK;
- removal of the Programmer's products from the Platform;
- legal action, including litigation, for damages, injunctive relief, and recovery of costs and expenses; and
- any other remedy available under applicable law or contract.

The Programmer may be held liable for all losses, damages, costs, and expenses (including reasonable legal fees) arising from or in connection with any breach. Nothing in this document limits the Company's right to pursue any remedy at law or in equity.

---

## 7. Governing Law and Jurisdiction

This document and any dispute or claim arising out of or in connection with it (including non-contractual disputes or claims) shall be governed by and construed in accordance with the laws of **England and Wales**. The courts of **England and Wales** shall have **non-exclusive** jurisdiction to settle any such dispute or claim.

---

## 8. Miscellaneous

8.1 **Severability.** If any provision of this document is held to be invalid or unenforceable, the remaining provisions shall continue in full force and effect.

8.2 **No waiver.** No failure or delay by the Company in exercising any right or remedy shall operate as a waiver thereof. Any waiver must be in writing and signed by the Company.

8.3 **Entire agreement.** This document, together with any separate agreement between the Programmer and the Company governing use of the Platform or Vendor Portal, constitutes the entire agreement between the parties regarding programmer obligations and prohibited conduct in relation to the SDK and Products. It supplements and does not replace the Company's general terms, policies, or Vendor Agreement where applicable.

8.4 **Contact.** For questions regarding this document or to report a potential breach, contact the Company at **support@themarketrobo.com** or through the contact details published at **https://www.themarketrobo.com/**.

---

**TMKR GLOBAL, LLC**  
**The Market Robo**  
**https://www.themarketrobo.com/**

*This document is provided for the protection of the Platform and its users. The Company recommends that programmers obtain independent legal advice if they have questions about their obligations.*
