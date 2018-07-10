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
| ...
| Force Tags | 3_NODE_SINGLE_LINK_TOPO | PERFTEST | HW_ENV | MRR
| ... | NIC_Intel-X520-DA2 | ETH | L2BDMACLRN | FEATURE | ACL | ACL_STATELESS
| ... | IACL | ACL50 | 10k_FLOWS
| ...
| Suite Setup | Run Keywords
| ... | Set up 3-node performance topology with DUT's NIC model | L2
| ... | Intel-X520-DA2
| ... | AND | Set up performance test suite with ACL
| Suite Teardown | Tear down 3-node performance topology
| ...
| Test Setup | Set up performance test
| ...
| Test Teardown | Tear down performance mrr test
| ...
| Test Template | Local template
| ...
| Documentation | *Raw results L2BD test cases with ACL*
| ...
| ... | *[Top] Network Topologies:* TG-DUT1-DUT2-TG 3-node circular topology\
| ... | with single links between nodes.
| ... | *[Enc] Packet Encapsulations:* Eth-IPv4-UDP for L2 switching of IPv4.
| ... | *[Cfg] DUT configuration:* DUT1 is configured with L2 bridge domain\
| ... | and MAC learning enabled. DUT2 is configured with L2 cross-connects.\
| ... | Required ACL rules are applied to input paths of both DUT1 intefaces.\
| ... | DUT1 and DUT2 are tested with 2p10GE NIC X520 Niantic by Intel.\
| ... | *[Ver] TG verification:* In MaxReceivedRate tests TG sends traffic\
| ... | at line rate and reports total received/sent packets over trial period.\
| ... | Test packets are generated by TG on\
| ... | links to DUTs. TG traffic profile contains two L3 flow-groups\
| ... | (flow-group per direction, ${flows_per_dir} flows per flow-group) with\
| ... | all packets containing Ethernet header, IPv4 header with UDP header and\
| ... | static payload. MAC addresses are matching MAC addresses of the TG node\
| ... | interfaces.
| ... | *[Ref] Applicable standard specifications:* RFC2544.

*** Variables ***
# X520-DA2 bandwidth limit
| ${s_limit}= | ${10000000000}

# ACL test setup
| ${acl_action}= | permit
| ${acl_apply_type}= | input
| ${no_hit_aces_number}= | 50
| ${flows_per_dir}= | 10k

# starting points for non-hitting ACLs
| ${src_ip_start}= | 30.30.30.1
| ${dst_ip_start}= | 40.40.40.1
| ${ip_step}= | ${1}
| ${sport_start}= | ${1000}
| ${dport_start}= | ${1000}
| ${port_step}= | ${1}
| ${trex_stream1_subnet}= | 10.10.10.0/24
| ${trex_stream2_subnet}= | 20.20.20.0/24

# Traffic profile:
| ${traffic_profile} | trex-sl-3n-ethip4udp-10u1000p-conc

*** Keywords ***
| Local template
| | [Documentation]
| | ... | [Cfg] DUT runs L2BD config with ACLs with ${phy_cores} phy
| | ... | core(s).
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
| | Set Test Variable | ${framesize}
| | ${get_framesize}= | Get Frame Size | ${framesize}
| | ${max_rate}= | Calculate pps | ${s_limit} | ${get_framesize}
| | ...
| | Given Add worker threads and rxqueues to all DUTs | ${phy_cores} | ${rxq}
| | And Add PCI devices to all DUTs
| | And Run Keyword If | ${get_framesize} < ${1522}
| | ... | Add no multi seg to all DUTs
| | And Apply startup configuration on all VPP DUTs
| | When Initialize L2 bridge domain with IPv4 ACLs on DUT1 in 3-node circular topology
| | Then Traffic should pass with maximum rate
| | ... | ${max_rate}pps | ${framesize} | ${traffic_profile}

*** Test Cases ***
| tc01-64B-1t1c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | 64B | 1C
| | phy_cores=${1} | framesize=${64}

| tc02-1518B-1t1c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | 1518B | 1C
| | phy_cores=${1} | framesize=${1518}

| tc03-9000B-1t1c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | 9000B | 1C
| | phy_cores=${1} | framesize=${9000}

| tc04-IMIX-1t1c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | IMIX | 1C
| | phy_cores=${1} | framesize=IMIX_v4_1

| tc05-64B-2t2c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | 64B | 2C
| | phy_cores=${2} | framesize=${64}

| tc06-1518B-2t2c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | 1518B | 2C
| | phy_cores=${2} | framesize=${1518}

| tc07-9000B-2t2c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | 9000B | 2C
| | phy_cores=${2} | framesize=${9000}

| tc08-IMIX-2t2c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | IMIX | 2C
| | phy_cores=${2} | framesize=IMIX_v4_1

| tc09-64B-4t4c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | 64B | 4C
| | phy_cores=${4} | framesize=${64}

| tc10-1518B-4t4c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | 1518B | 4C
| | phy_cores=${4} | framesize=${1518}

| tc11-9000B-4t4c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | 9000B | 4C
| | phy_cores=${4} | framesize=${9000}

| tc12-IMIX-4t4c-eth-l2bdbasemaclrn-iacl50-stateless-flows10k-mrr
| | [Tags] | IMIX | 4C
| | phy_cores=${4} | framesize=IMIX_v4_1
