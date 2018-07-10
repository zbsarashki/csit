# Copyright (c) 2018 Cisco and/or its affiliates.
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
| Resource | resources/libraries/robot/overlay/lisp_static_adjacency.robot
| Variables | resources/test_data/lisp/performance/lisp_static_adjacency.py
| ...
| Force Tags | 3_NODE_SINGLE_LINK_TOPO | PERFTEST | HW_ENV | MRR
| ... | NIC_Intel-X520-DA2 | IP4FWD | ENCAP | LISP | IP4UNRLAY | IP4OVRLAY
| ...
| Suite Setup | Set up 3-node performance topology with DUT's NIC model
| ... | L3 | Intel-X520-DA2
| Suite Teardown | Tear down 3-node performance topology
| ...
| Test Setup | Set up performance test
| ...
| Test Teardown | Tear down performance mrr test
| ...
| Test Template | Local template
| ...
| Documentation | *Raw results Lisp test cases*
| ...
| ... | *[Top] Network Topologies:* TG-DUT1-DUT2-TG 3-node circular topology\
| ... | with single links between nodes.
| ... | *[Enc] Packet Encapsulations:* Eth-IPv4-LISP-IPv4 on DUT1-DUT2,\
| ... | Eth-IPv4 on TG-DUTn for IPv4 routing over LISPoIPv4 tunnel.
| ... | *[Cfg] DUT configuration:* DUT1 and DUT2 are configured with IPv4\
| ... | routing and static routes. LISPoIPv4 tunnel is configured between DUT1\
| ... | and DUT2. DUT1 and DUT2 tested with 2p10GE NIC X520 Niantic by Intel.
| ... | *[Ver] TG verification:* In MaxReceivedRate test TG sends traffic
| ... | at line rate and reports total received/sent packets over trial period.
| ... | Test packets are generated by TG on links to DUTs. TG traffic profile
| ... | contains two L3 flow-groups (flow-group per direction, 253 flows per
| ... | flow-group) with all packets containing Ethernet header, IPv4 header
| ... | with IP protocol=61 and static payload. MAC addresses are matching MAC
| ... | addresses of the TG node interfaces.
| ... | *[Ref] Applicable standard specifications:* RFC6830.

*** Variables ***
# X520-DA2 bandwidth limit
| ${s_limit}= | ${10000000000}
| ${lisp_overhead}= | ${8}
# Traffic profile:
| ${traffic_profile}= | trex-sl-3n-ethip4-ip4src253

*** Keywords ***
| Local template
| | [Documentation]
| | ... | [Cfg] DUT runs IPv4 LISP remote static mappings and whitelist filters\
| | ... | config.
| | ... | Each DUT uses ${phy_cores} physical core(s) for worker threads.
| | ... | [Ver] Measure MaxReceivedRate for ${framesize}B frames using single\
| | ... | trial throughput test.
| | ...
| | ... | *Arguments:*
| | ... | - framesize - Framesize in Bytes in integer or string (IMIX_v4_1).
| | ... | Type: integer, string
| | ... | - phy_cores - Number of physical cores. Type: integer
| | ... | - rxq - Number of RX queues, default value: ${None}. Type: integer
| | ...
| | [Arguments] | ${phy_cores} | ${framesize} | ${rxq}=${None}
| | ...
| | # Test Variables required for test execution and test teardown
| | Set Test Variable | ${framesize}
| | ${get_framesize}= | Get Frame Size | ${framesize}
| | ${max_rate}= | Calculate pps | ${s_limit}
| | ... | ${get_framesize + ${lisp_overhead}}
| | ...
| | Given Add worker threads and rxqueues to all DUTs | ${phy_cores} | ${rxq}
| | And Add PCI devices to all DUTs
| | And Run Keyword If | ${get_framesize + ${lisp_overhead}} < ${1522}
| | ... | Add no multi seg to all DUTs
| | And Apply startup configuration on all VPP DUTs
| | When Initialize LISP IPv4 forwarding in 3-node circular topology
| | ... | ${dut1_to_dut2_ip4} | ${dut1_to_tg_ip4} | ${dut2_to_dut1_ip4}
| | ... | ${dut2_to_tg_ip4} | ${prefix4}
| | And Configure LISP topology in 3-node circular topology
| | ... | ${dut1} | ${dut1_if2} | ${NONE}
| | ... | ${dut2} | ${dut2_if1} | ${NONE}
| | ... | ${duts_locator_set} | ${dut1_ip4_eid} | ${dut2_ip4_eid}
| | ... | ${dut1_ip4_static_adjacency} | ${dut2_ip4_static_adjacency}
| | Then Traffic should pass with maximum rate
| | ... | ${max_rate}pps | ${framesize} | ${traffic_profile}

*** Test Cases ***
| tc01-64B-1t1c-ethip4lispip4-ip4base-mrr
| | [Tags] | 64B | 1C
| | phy_cores=${1} | framesize=${64}

| tc02-1480B-1t1c-ethip4lispip4-ip4base-mrr
| | [Tags] | 1480B | 1C
| | phy_cores=${1} | framesize=${1480}

| tc03-9000B-1t1c-ethip4lispip4-ip4base-mrr
| | [Tags] | 9000B | 1C
| | phy_cores=${1} | framesize=${9000}

| tc04-IMIX-1t1c-ethip4lispip4-ip4base-mrr
| | [Tags] | IMIX | 1C
| | phy_cores=${1} | framesize=IMIX_v4_1

| tc05-64B-2t2c-ethip4lispip4-ip4base-mrr
| | [Tags] | 64B | 2C
| | phy_cores=${2} | framesize=${64}

| tc06-1480B-2t2c-ethip4lispip4-ip4base-mrr
| | [Tags] | 1480B | 2C
| | phy_cores=${2} | framesize=${1480}

| tc07-9000B-2t2c-ethip4lispip4-ip4base-mrr
| | [Tags] | 9000B | 2C
| | phy_cores=${2} | framesize=${9000}

| tc08-IMIX-2t2c-ethip4lispip4-ip4base-mrr
| | [Tags] | IMIX | 2C
| | phy_cores=${2} | framesize=IMIX_v4_1

| tc09-64B-4t4c-ethip4lispip4-ip4base-mrr
| | [Tags] | 64B | 4C
| | phy_cores=${4} | framesize=${64}

| tc10-1480B-4t4c-ethip4lispip4-ip4base-mrr
| | [Tags] | 1480B | 4C
| | phy_cores=${4} | framesize=${1480}

| tc11-9000B-4t4c-ethip4lispip4-ip4base-mrr
| | [Tags] | 9000B | 4C
| | phy_cores=${4} | framesize=${9000}

| tc12-IMIX-4t4c-ethip4lispip4-ip4base-mrr
| | [Tags] | IMIX | 4C
| | phy_cores=${4} | framesize=IMIX_v4_1
