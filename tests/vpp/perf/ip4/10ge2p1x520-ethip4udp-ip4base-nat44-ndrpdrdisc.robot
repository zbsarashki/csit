# Copyright (c) 2017 Cisco and/or its affiliates.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

*** Settings ***
| Resource | resources/libraries/robot/performance/performance_setup.robot
| Resource | resources/libraries/robot/ip/nat.robot
| Resource | resources/libraries/robot/shared/traffic.robot
| ...
| Force Tags | 3_NODE_SINGLE_LINK_TOPO | PERFTEST | HW_ENV | NDRPDRDISC
| ... | NIC_Intel-X520-DA2 | ETH | IP4FWD | FEATURE | NAT44 | BASE
| ...
| Suite Setup | Set up 3-node performance topology with DUT's NIC model
| ... | L3 | Intel-X520-DA2
| Suite Teardown | Tear down 3-node performance topology
| ...
| Test Setup | Set up performance test
| ...
| Test Teardown | Tear down performance discovery test with NAT
| ... | ${min_rate}pps | ${framesize} | ${traffic_profile}
| ...
| Documentation | *NAT44 performance test cases*
| ...
| ... | *High level description*
| ...
| ... | - NDR and PDR tests
| ... | - 3-node topology, TG-DUT1-DUT2-TG, NAT44 is enabled between DUTs.
| ... | - Cores / threads: 1t1c, 2t2c, and 4t4c
| ... | - Framesize: 64B, 1518B, IMIX
| ... | - Packet: ETH / IP(src, dst) / UDP(src_port, dst_port) / payload
| ...
| ... | *Low level description*
| ...
| ... | *[Top] Network Topologies:* TG-DUT1-DUT2-TG 3-node circular topology
| ... | with single links between nodes.
| ... | *[Enc] Packet Encapsulations:* Eth-IPv4-UDP for IPv4 routing.
| ... | *[Cfg] DUT configuration:* DUT1 and DUT2 are configured with IPv4
| ... | routing and two static IPv4 /24 and IPv4/20 route entries. DUT1 and DUT2
| ... | tested with 2p10GE NIC X520 Niantic by Intel.
| ... | *[Ver] TG verification:* TG finds and reports throughput NDR (Non Drop
| ... | Rate) with zero packet loss tolerance or throughput PDR (Partial Drop
| ... | Rate) with non-zero packet loss tolerance (LT) expressed in percentage
| ... | of packets transmitted. NDR and PDR are discovered for different
| ... | Ethernet L2 frame sizes using either binary search or linear search
| ... | algorithms with configured starting rate and final step that determines
| ... | throughput measurement resolution. Test packets are generated by TG on
| ... | links to DUTs. TG traffic profile contains two L3 flow-groups
| ... | (flow-group per direction, one flow per flow-group) with all packets
| ... | containing Ethernet header, IPv4 header with UDP header and static
| ... | payload. MAC addresses are matching MAC addresses of the TG node
| ... | interfaces.
| ... | *[Ref] Applicable standard specifications:* RFC2544.

*** Variables ***
# X520-DA2 bandwidth limit
| ${s_limit} | ${10000000000}
# Traffic profile:
| ${traffic_profile} | trex-sl-3n-ethip4udp-1u1p

*** Keywords ***
| Discover NDR or PDR for IPv4 routing with NAT44
| | ...
| | [Arguments] | ${wt} | ${rxq} | ${framesize} | ${min_rate} | ${search_type}
| | ...
| | Set Test Variable | ${framesize}
| | Set Test Variable | ${min_rate}
| | ${max_rate}= | Calculate pps | ${s_limit} | ${framesize}
| | ${binary_min}= | Set Variable | ${min_rate}
| | ${binary_max}= | Set Variable | ${max_rate}
| | ${threshold}= | Set Variable | ${min_rate}
| | ${get_framesize}= | Get Frame Size | ${framesize}
| | ...
| | Given Add '${wt}' worker threads and '${rxq}' rxqueues in 3-node single-link circular topology
| | And Add PCI devices to DUTs in 3-node single link topology
| | And Run Keyword If | ${get_framesize} < ${1522}
| | ... | Add no multi seg to all DUTs
| | And Add NAT to all DUTs
| | And Apply startup configuration on all VPP DUTs
| | When Initialize NAT44 in 3-node circular topology
| | Then Run Keyword If | '${search_type}' == 'NDR'
| | ... | Find NDR using binary search and pps
| | ... | ${framesize} | ${binary_min} | ${binary_max} | ${traffic_profile}
| | ... | ${min_rate} | ${max_rate} | ${threshold}
| | ... | ELSE IF | '${search_type}' == 'PDR'
| | ... | Find PDR using binary search and pps
| | ... | ${framesize} | ${binary_min} | ${binary_max} | ${traffic_profile}
| | ... | ${min_rate} | ${max_rate} | ${threshold}
| | ... | ${perf_pdr_loss_acceptance} | ${perf_pdr_loss_acceptance_type}

*** Test Cases ***
| tc01-64B-1t1c-ethip4-ip4base-snat-1u-1p-ndrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 1 thread, 1 phy core,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find NDR for 64 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 64B | 1T1C | STHREAD | NDRDISC
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=1 | rxq=1 | framesize=${64} | min_rate=${100000} | search_type=NDR

| tc02-64B-1t1c-ethip4-ip4base-snat-1u-1p-pdrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 1 thread, 1 phy core,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find PDR for 64 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 64B | 1T1C | STHREAD | PDRDISC | SKIP_PATCH
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=1 | rxq=1 | framesize=${64} | min_rate=${100000} | search_type=PDR

| tc03-1518B-1t1c-ethip4-ip4base-snat-1u-1p-ndrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 1 thread, 1 phy core,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find NDR for 1518 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 1518B | 1T1C | STHREAD | NDRDISC
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=1 | rxq=1 | framesize=${1518} | min_rate=${100000} | search_type=NDR

| tc04-1518B-1t1c-ethip4-ip4base-snat-1u-1p-pdrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 1 thread, 1 phy core,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find PDR for 1518 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 1518B | 1T1C | STHREAD | PDRDISC | SKIP_PATCH
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=1 | rxq=1 | framesize=${1518} | min_rate=${100000} | search_type=PDR

| tc05-IMIX-1t1c-ethip4-ip4base-snat-1u-1p-ndrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 1 thread, 1 phy core,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find NDR for IMIX frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | IMIX | 1T1C | STHREAD | NDRDISC
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=1 | rxq=1 | framesize=IMIX_v4_1 | min_rate=${100000} | search_type=NDR

| tc06-IMIX-1t1c-ethip4-ip4base-snat-1u-1p-pdrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 1 thread, 1 phy core,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find PDR for IMIX frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | IMIX | 1T1C | STHREAD | PDRDISC | SKIP_PATCH
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=1 | rxq=1 | framesize=IMIX_v4_1 | min_rate=${100000} | search_type=PDR

| tc07-64B-2t2c-ethip4-ip4base-snat-1u-1p-ndrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 2 threads, 2 phy cores,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find NDR for 64 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 64B | 2T2C | MTHREAD | NDRDISC
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=2 | rxq=1 | framesize=${64} | min_rate=${100000} | search_type=NDR

| tc08-64B-2t2c-ethip4-ip4base-snat-1u-1p-pdrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 2 threads, 2 phy cores,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find PDR for 64 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 64B | 2T2C | MTHREAD | PDRDISC | SKIP_PATCH
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=2 | rxq=1 | framesize=${64} | min_rate=${100000} | search_type=PDR

| tc09-1518B-2t2c-ethip4-ip4base-snat-1u-1p-ndrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 2 threads, 2 phy cores,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find NDR for 1518 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 1518B | 2T2C | MTHREAD | NDRDISC
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=2 | rxq=1 | framesize=${1518} | min_rate=${100000} | search_type=NDR

| tc10-1518B-2t2c-ethip4-ip4base-snat-1u-1p-pdrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 2 threads, 2 phy cores,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find PDR for 1518 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 1518B | 2T2C | MTHREAD | PDRDISC | SKIP_PATCH
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=2 | rxq=1 | framesize=${1518} | min_rate=${100000} | search_type=PDR

| tc11-IMIX-2t2c-ethip4-ip4base-snat-1u-1p-ndrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 2 threads, 2 phy cores,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find NDR for IMIX frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | IMIX | 2T2C | MTHREAD | NDRDISC
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=2 | rxq=1 | framesize=IMIX_v4_1 | min_rate=${100000} | search_type=NDR

| tc12-IMIX-2t2c-ethip4-ip4base-snat-1u-1p-pdrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 2 threads, 2 phy cores,\
| | ... | 1 receive queue per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find PDR for IMIX frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | IMIX | 2T2C | MTHREAD | PDRDISC | SKIP_PATCH
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=2 | rxq=1 | framesize=IMIX_v4_1 | min_rate=${100000} | search_type=PDR

| tc13-64B-4t4c-ethip4-ip4base-snat-1u-1p-ndrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 4 threads, 4 phy cores,\
| | ... | 2 receive queues per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find NDR for 64 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 64B | 4T4C | MTHREAD | NDRDISC
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=4 | rxq=2 | framesize=${64} | min_rate=${100000} | search_type=NDR

| tc14-64B-4t4c-ethip4-ip4base-snat-1u-1p-pdrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 4 threads, 4 phy cores,\
| | ... | 2 receive queues per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find PDR for 64 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 64B | 4T4C | MTHREAD | PDRDISC | SKIP_PATCH
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=4 | rxq=2 | framesize=${64} | min_rate=${100000} | search_type=PDR

| tc15-1518B-4t4c-ethip4-ip4base-snat-1u-1p-ndrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 4 threads, 4 phy cores,\
| | ... | 2 receive queues per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find NDR for 1518 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 1518B | 4T4C | MTHREAD | NDRDISC
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=4 | rxq=2 | framesize=${1518} | min_rate=${100000} | search_type=NDR

| tc16-1518B-4t4c-ethip4-ip4base-snat-1u-1p-pdrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 4 threads, 4 phy cores,\
| | ... | 2 receive queues per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find PDR for 1518 Byte frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | 1518B | 4T4C | MTHREAD | PDRDISC | SKIP_PATCH
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=4 | rxq=2 | framesize=${1518} | min_rate=${100000} | search_type=PDR

| tc17-IMIX-4t4c-ethip4-ip4base-snat-1u-1p-ndrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 4 threads, 4 phy cores,\
| | ... | 2 receive queues per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find NDR for IMIX frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | IMIX | 4T4C | MTHREAD | NDRDISC
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=4 | rxq=2 | framesize=IMIX_v4_1 | min_rate=${100000} | search_type=NDR

| tc18-IMIX-4t4c-ethip4-ip4base-snat-1u-1p-pdrdisc
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with 4 threads, 4 phy cores,\
| | ... | 2 receive queues per NIC port. NAT44 is configured between DUTs -\
| | ... | 1 user and 1 port (session) per user.
| | ... | [Ver] Find PDR for IMIX frames using binary search start at 10GE\
| | ... | linerate, step 100kpps.
| | ...
| | [Tags] | IMIX | 4T4C | MTHREAD | PDRDISC | SKIP_PATCH
| | ...
| | [Template] | Discover NDR or PDR for IPv4 routing with NAT44
| | wt=4 | rxq=2 | framesize=IMIX_v4_1 | min_rate=${100000} | search_type=PDR
