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
| ... | NIC_Intel-X710 | ETH | L2BDMACLRN | SCALE | L2BDBASE | FIB_10K
| ...
| Suite Setup | Set up 3-node performance topology with DUT's NIC model
| ... | L2 | Intel-X710
| Suite Teardown | Tear down 3-node performance topology
| ...
| Test Setup | Set up performance test
| ...
| Test Teardown | Tear down performance mrr test
| ...
| Test Template | Local template
| ...
| Documentation | *Raw results for L2BD test cases*
| ...
| ... | *[Top] Network Topologies:* TG-DUT1-DUT2-TG 3-node circular topology\
| ... | with single links between nodes.
| ... | *[Enc] Packet Encapsulations:* Eth-IPv4 for L2 switching of IPv4.
| ... | *[Cfg] DUT configuration:* DUT1 and DUT2 are configured with L2 bridge-\
| ... | domain and MAC learning enabled. DUT1 and DUT2 tested with 2p10GE NI
| ... | X710 by Intel.
| ... | *[Ver] TG verification:* In MaxReceivedRate tests TG sends traffic\
| ... | at line rate and reports total received/sent packets over trial period.\
| ... | Test packets are generated by TG on\
| ... | links to DUTs. TG traffic profile contains two L3 flow-groups\
| ... | (flow-group per direction, 5k flows per flow-group) with all packets\
| ... | containing Ethernet header, IPv4 header with IP protocol=61 and static\
| ... | payload. MAC addresses ranges are incremented as follows:
| ... | port01_src ca:fe:00:00:00:00 - port01_src ca:fe:00:00:13:87,\
| ... | port01_dst fa:ce:00:00:00:00 - port01_dst fa:ce:00:00:13:87,\
| ... | port02_src fa:ce:00:00:00:00 - port02_src fa:ce:00:00:13:87,\
| ... | port02_dst ca:fe:00:00:00:00 - port02_dst ca:fe:00:00:13:87,\
| ... | *[Ref] Applicable standard specifications:* RFC2544.

*** Variables ***
# X710-DA2 bandwidth limit
| ${s_limit}= | ${10000000000}
# Traffic profile:
| ${traffic_profile}= | trex-sl-3n-ethip4-macsrc5kdst5k

*** Keywords ***
| Local template
| | [Documentation]
| | ... | [CFG] DUT runs L2BD switching config with ${phy_cores} phy
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
| | [Arguments] | ${framesize} | ${phy_cores} | ${rxq}=${None}
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
| | When Initialize L2 bridge domain in 3-node circular topology
| | Then Traffic should pass with maximum rate
| | ... | ${max_rate}pps | ${framesize} | ${traffic_profile}

*** Test Cases ***
| tc01-64B-1t1c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 64B | 1C
| | framesize=${64} | phy_cores=${1}

| tc02-1518B-1t1c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 1518B | 1C
| | framesize=${1518} | phy_cores=${1}

| tc03-9000B-1t1c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 9000B | 1C
| | framesize=${9000} | phy_cores=${1}

| tc04-IMIX-1t1c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | IMIX_v4_1 | 1C
| | framesize=IMIX_v4_1 | phy_cores=${1}

| tc05-64B-2t2c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 64B | 2C
| | framesize=${64} | phy_cores=${2}

| tc06-1518B-2t2c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 1518B | 2C
| | framesize=${1518} | phy_cores=${2}

| tc07-9000B-2t2c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 9000B | 2C
| | framesize=${9000} | phy_cores=${2}

| tc08-IMIX-2t2c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | IMIX_v4_1 | 2C
| | framesize=IMIX_v4_1 | phy_cores=${2}

| tc09-64B-4t4c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 64B | 4C
| | framesize=${64} | phy_cores=${4}

| tc10-1518B-4t4c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 1518B | 4C
| | framesize=${1518} | phy_cores=${4}

| tc11-9000B-4t4c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 9000B | 4C
| | framesize=${9000} | phy_cores=${4}

| tc12-IMIX-4t4c-eth-l2dbscale10kmaclrn-mrr
| | [Tags] | 9000B | IMIX_v4_1
| | framesize=IMIX_v4_1 | phy_cores=${4}
