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
| Library | resources.libraries.python.Cop
| ...
| Force Tags | 3_NODE_SINGLE_LINK_TOPO | PERFTEST | HW_ENV | NDRPDRDISC
| ... | NIC_Intel-X520-DA2 | ETH | IP4FWD | FEATURE | COPWHLIST
| ...
| Suite Setup | Set up 3-node performance topology with DUT's NIC model
| ... | L3 | Intel-X520-DA2
| Suite Teardown | Tear down 3-node performance topology
| ...
| Test Setup | Set up performance test
| ...
| Test Teardown | Tear down performance discovery test | ${min_rate}pps
| ... | ${framesize} | ${traffic_profile}
| ...
| Test Template | Local template
| ...
| Documentation | *RFC2544: Pkt throughput IPv4 whitelist test cases*
| ...
| ... | *[Top] Network Topologies:* TG-DUT1-DUT2-TG 3-node circular topology
| ... | with single links between nodes.
| ... | *[Enc] Packet Encapsulations:* Eth-IPv4 for IPv4 routing.
| ... | *[Cfg] DUT configuration:* DUT1 and DUT2 are configured with IPv4
| ... | routing, two static IPv4 /24 routes and IPv4 COP security whitelist
| ... | ingress /24 filter entries applied on links TG - DUT1 and DUT2 - TG.
| ... | DUT1 and DUT2 tested with 2p10GE NIC X520 Niantic by Intel.
| ... | *[Ver] TG verification:* TG finds and reports throughput NDR (Non Drop
| ... | Rate) with zero packet loss tolerance or throughput PDR (Partial Drop
| ... | Rate) with non-zero packet loss tolerance (LT) expressed in percentage
| ... | of packets transmitted. NDR and PDR are discovered for different
| ... | Ethernet L2 frame sizes using either binary search or linear search
| ... | algorithms with configured starting rate and final step that determines
| ... | throughput measurement resolution. Test packets are generated by TG on
| ... | links to DUTs. TG traffic profile contains two L3 flow-groups
| ... | (flow-group per direction, 253 flows per flow-group) with all packets
| ... | containing Ethernet header, IPv4 header with IP protocol=61 and static
| ... | payload. MAC addresses are matching MAC addresses of the TG node
| ... | interfaces.
| ... | *[Ref] Applicable standard specifications:* RFC2544.

*** Variables ***
# X520-DA2 bandwidth limit
| ${s_limit} | ${10000000000}
# Traffic profile:
| ${traffic_profile} | trex-sl-3n-ethip4-ip4src253

*** Keywords ***
| Local template
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 routing config with ${wt} thread(s), ${wt}\
| | ... | phy core(s), ${rxq} receive queue(s) per NIC port.
| | ... | [Ver] Find NDR or PDR for ${framesize} frames using binary search\
| | ... | start at 10GE linerate.
| | ...
| | [Arguments] | ${phy_cores} | ${framesize} | ${search_type}
| | ... | ${rxq}=${None} | ${min_rate}=${50000}
| | ...
| | Set Test Variable | ${framesize}
| | Set Test Variable | ${min_rate}
| | ${get_framesize}= | Get Frame Size | ${framesize}
| | ${max_rate}= | Calculate pps | ${s_limit} | ${get_framesize}
| | ${binary_min}= | Set Variable | ${min_rate}
| | ${binary_max}= | Set Variable | ${max_rate}
| | ${threshold}= | Set Variable | ${min_rate}
| | Given Add worker threads and rxqueues to all DUTs | ${phy_cores} | ${rxq}
| | And Add PCI devices to all DUTs
| | And Run Keyword If | ${get_framesize} < ${1522}
| | ... | Add no multi seg to all DUTs
| | And Apply startup configuration on all VPP DUTs
| | When Initialize IPv4 forwarding in 3-node circular topology
| | And Add Fib Table | ${dut1} | 1
| | And Vpp Route Add | ${dut1} | 10.10.10.0 | 24 | vrf=1 | local=${TRUE}
| | And Add Fib Table | ${dut2} | 1
| | And Vpp Route Add | ${dut2} | 20.20.20.0 | 24 | vrf=1 | local=${TRUE}
| | And COP Add whitelist Entry | ${dut1} | ${dut1_if1} | ip4 | 1
| | And COP Add whitelist Entry | ${dut2} | ${dut2_if2} | ip4 | 1
| | And COP interface enable or disable | ${dut1} | ${dut1_if1} | enable
| | And COP interface enable or disable | ${dut2} | ${dut2_if2} | enable
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
| tc01-64B-1t1c-ethip4-ip4base-copwhtlistbase-ndrdisc
| | [Tags] | 64B | 1C | NDRDISC
| | phy_cores=${1} | framesize=${64}  | search_type=NDR

| tc02-64B-1t1c-ethip4-ip4base-copwhtlistbase-pdrdisc
| | [Tags] | 64B | 1C | PDRDISC | SKIP_PATCH
| | phy_cores=${1} | framesize=${64}  | search_type=PDR

| tc03-1518B-1t1c-ethip4-ip4base-copwhtlistbase-ndrdisc
| | [Tags] | 1518B | 1C | NDRDISC
| | phy_cores=${1} | framesize=${1518}  | search_type=NDR

| tc04-1518B-1t1c-ethip4-ip4base-copwhtlistbase-pdrdisc
| | [Tags] | 1518B | 1C | PDRDISC | SKIP_PATCH
| | phy_cores=${1} | framesize=${1518}  | search_type=PDR

| tc05-9000B-1t1c-ethip4-ip4base-copwhtlistbase-ndrdisc
| | [Tags] | 9000B | 1C | NDRDISC
| | phy_cores=${1} | framesize=${9000} | search_type=NDR

| tc06-9000B-1t1c-ethip4-ip4base-copwhtlistbase-pdrdisc
| | [Tags] | 9000B | 1C | PDRDISC | SKIP_PATCH
| | phy_cores=${1} | framesize=${9000} | search_type=PDR

| tc07-64B-2t2c-ethip4-ip4base-copwhtlistbase-ndrdisc
| | [Tags] | 64B | 2C | NDRDISC
| | phy_cores=${2} | framesize=${64}  | search_type=NDR

| tc08-64B-2t2c-ethip4-ip4base-copwhtlistbase-pdrdisc
| | [Tags] | 64B | 2C | PDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${64}  | search_type=PDR

| tc09-1518B-2t2c-ethip4-ip4base-copwhtlistbase-ndrdisc
| | [Tags] | 1518B | 2C | NDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${1518}  | search_type=NDR

| tc10-1518B-2t2c-ethip4-ip4base-copwhtlistbase-pdrdisc
| | [Tags] | 1518B | 2C | PDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${1518}  | search_type=PDR

| tc11-9000B-2t2c-ethip4-ip4base-copwhtlistbase-ndrdisc
| | [Tags] | 9000B | 2C | NDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${9000} | search_type=NDR

| tc12-9000B-2t2c-ethip4-ip4base-copwhtlistbase-pdrdisc
| | [Tags] | 9000B | 2C | PDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${9000} | search_type=PDR

| tc13-64B-4t4c-ethip4-ip4base-copwhtlistbase-ndrdisc
| | [Tags] | 64B | 4C | NDRDISC
| | phy_cores=${4} | framesize=${64}  | search_type=NDR

| tc14-64B-4t4c-ethip4-ip4base-copwhtlistbase-pdrdisc
| | [Tags] | 64B | 4C | PDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${64}  | search_type=PDR

| tc15-1518B-4t4c-ethip4-ip4base-copwhtlistbase-ndrdisc
| | [Tags] | 1518B | 4C | NDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${1518}  | search_type=NDR

| tc16-1518B-4t4c-ethip4-ip4base-copwhtlistbase-pdrdisc
| | [Tags] | 1518B | 4C | PDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${1518}  | search_type=PDR

| tc17-9000B-4t4c-ethip4-ip4base-copwhtlistbase-ndrdisc
| | [Tags] | 9000B | 4C | NDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${9000} | search_type=NDR

| tc18-9000B-4t4c-ethip4-ip4base-copwhtlistbase-pdrdisc
| | [Tags] | 9000B | 4C | PDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${9000} | search_type=PDR
