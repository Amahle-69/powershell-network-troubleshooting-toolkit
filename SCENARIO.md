
# PowerShell Network Troubleshooting Toolkit

## 1. Business Scenario

Mahlangu Business Solutions is a fictional company whose IT Support team helps employees troubleshoot workstation connectivity problems.

An employee submits the following Help Desk ticket:

"My laptop is connected to Wi-Fi, but I cannot open the company website."

The technician needs a structured approach to determine whether the issue may involve IP configuration, network reachability, DNS resolution, or connectivity to a particular TCP service.

## 2. Business Problem

Network connection problems can have several possible causes. A workstation may have an IP configuration issue, be unable to reach a destination, fail to resolve a hostname, or be unable to connect to a required service.

Checking these conditions manually can be repetitive and may lead to incomplete troubleshooting notes.

## 3. Proposed Solution

Develop a PowerShell troubleshooting toolkit that performs selected read-only network checks and produces a report containing observed results, status classifications, and recommended next steps.

The initial version will run locally on Windows and use known test destinations supplied by the technician. It will not change network adapter settings or attempt automatic remediation.

## 4. Project Objectives

- Inspect IP configuration without unnecessarily publishing private network details.
- Test reachability to a selected destination.
- Check DNS name resolution for a selected hostname.
- Test TCP connectivity to a specified host and port.
- Distinguish successful checks, failed checks, and checks that could not be completed.
- Generate a CSV troubleshooting report.
- Include automated tests for the report structure and diagnostic logic.
- Document limitations and recommendations.
- Publish the project using Git and GitHub.

## 5. Fictional Help Desk Scenarios

### Scenario A: Website hostname does not resolve

An employee cannot access a company website. The DNS lookup fails.

The toolkit should record the lookup result and recommend checking the hostname, DNS configuration, and whether the name is expected to resolve from the current network.

### Scenario B: Destination is not reachable

A connectivity test does not receive a reply from its destination.

The toolkit should record that the destination did not respond to that test. It must not conclude that the entire network is down because a destination may block diagnostic traffic.

### Scenario C: DNS resolves but a service connection fails

A hostname resolves to an address, but the TCP connection to the selected service port fails.

The report should recommend investigating service availability, routing, firewall rules, and whether the destination is expected to accept connections on that port.

### Scenario D: All selected checks succeed

The selected network checks succeed.

The toolkit should report that no issue was found by those checks while explaining that this does not guarantee every application or network service is working.

## 6. Planned Workflow

1. Collect selected IP configuration information.
2. Test connectivity to a chosen destination.
3. Resolve a specified hostname.
4. Test TCP connectivity to a specified host and port.
5. Record outcomes using consistent status labels.
6. Generate a structured CSV report with findings and recommendations.
7. Run automated tests against report generation and diagnostic logic.
8. Review output for private information before publishing.

## 7. Technology Stack

- Scripting language: Windows PowerShell 5.1
- Editor: Visual Studio Code
- Operating environment: Windows 11
- Network diagnostics: Windows networking cmdlets and utilities
- Data interchange: CSV
- Version control: Git
- Repository hosting: GitHub

## 8. Safety and Privacy

The toolkit performs diagnostic checks only.

It will not reset network adapters, flush DNS caches, modify firewall rules, change IP configuration, or make other network changes automatically.

Reports intended for publication must not expose unnecessary private IP addresses, MAC addresses, computer names, usernames, or internal network details.

## 9. Limitations

- A failed ping does not by itself prove that a host or network is unavailable.
- DNS resolution can vary by network, resolver, and configured name.
- A failed TCP connection may result from filtering, routing, service availability, or an incorrect target.
- Results may change depending on the network connection and the time of testing.
- The toolkit does not replace a full network investigation.

## 10. Expected Outcome

The completed project should demonstrate how PowerShell can collect network diagnostic evidence, organise troubleshooting results, recommend sensible next steps, and create a reusable report suitable for Help Desk documentation.
