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
| ... | NIC_Intel-X520-DA2 | SRv6 | IP6FWD | FEATURE | SRv6_PROXY
| ... | SRv6_PROXY_MASQ | MEMIF | LXC
| ...
| Suite Setup | Run Keywords
| ... | Set up 3-node performance topology with DUT's NIC model | L3
| ... | Intel-X520-DA2
| ... | AND | Set up performance test suite with MEMIF
| ... | AND | Set up performance test suite with Masquerading SRv6 proxy
| ... | AND | Set up performance topology with containers
| ...
| Suite Teardown | Tear down 3-node performance topology with container
| ...
| Test Setup | Set up performance test
| ...
| Test Teardown | Tear down mrr test with SRv6 with encapsulation
| ...
| Documentation | *Raw results for Segment routing over IPv6 dataplane with\
| ... | Masquerading SRv6 proxy test cases*
| ...
| ... | *[Top] Network Topologies:* TG-DUT1-DUT2-TG 3-node circular topology\
| ... | with single links between nodes.
| ... | *[Enc] Packet Encapsulations:* Eth-IPv6-SRH-IPv6 on DUT1-DUT2, DUTn-LXC\
| ... | and DUTn->TG, Eth-IPv6 on TG->DUTn for IPv6 routing over SRv6.
| ... | *[Cfg] DUT configuration:* DUT1 and DUT2 are configured with IPv6\
| ... | routing and static route, SR policy and steering policy for one\
| ... | direction and one SR behaviour (function) - End.AM - for other\
| ... | direction. DUT1 and DUT2 are tested with 2p10GE NIC X520 Niantic\
| ... | by Intel.
| ... | *[Ver] TG verification:* In MaxReceivedRate tests TG sends traffic\
| ... | at line rate and reports total received/sent packets over trial period.\
| ... | Test packets are generated by TG on\
| ... | links to DUTs. TG traffic profile contains two L3 flow-groups\
| ... | (flow-group per direction, 253 flows per flow-group) with\
| ... | all packets containing Ethernet header,IPv6 header with static payload.\
| ... | MAC addresses are matching MAC addresses of the TG node interfaces.
| ... | *[Ref] Applicable standard specifications:* SRv6 Network Programming -\
| ... | draft 3 and Segment Routing for Service Chaining - internet draft 01.

*** Variables ***
# X520-DA2 bandwidth limit
| ${s_limit}= | ${10000000000}
# SIDs
| ${dut1_sid1}= | 2002:1::
| ${dut1_sid2}= | 2003:2::
| ${dut1_bsid}= | 2002:1::1
| ${dut2_sid1}= | 2002:2::
| ${dut2_sid2}= | 2003:1::
| ${dut2_bsid}= | 2003:1::1
| ${out_sid1_1}= | 2002:3::
| ${out_sid1_2}= | 2002:4::
| ${out_sid2_1}= | 2003:3::
| ${out_sid2_2}= | 2003:4::
| ${sid_prefix}= | ${64}
# IP settings
| ${tg_if1_ip6_subnet}= | 2001:1::
| ${tg_if2_ip6_subnet}= | 2001:2::
| ${dut1_if1_ip6}= | 2001:1::1
| ${dut1_if2_ip6}= | 2001:3::1
| ${dut1-memif-1-if1_ip6}= | 3001:1::1
| ${dut1-memif-1-if2_ip6}= | 3001:1::2
| ${dut1_nh}= | 4002::
| ${dut2_if1_ip6}= | 2001:3::2
| ${dut2_if2_ip6}= | 2001:2::1
| ${dut2-memif-1-if1_ip6}= | 3002:1::1
| ${dut2-memif-1-if2_ip6}= | 3002:1::2
| ${dut2_nh}= | 4001::
| ${prefix}= | ${64}
# outer IPv6 header + SRH with 3 SIDs: 40+(8+3*16)B
| ${srv6_overhead_3sids}= | ${96}
# Traffic profile:
| ${traffic_profile}= | trex-sl-3n-ethip6-ip6src253
# LXC container
| ${container_count}= | ${1}
| ${container_engine}= | LXC
| ${container_image}= | ${EMPTY}
| ${container_install_dkms}= | ${FALSE}
| ${container_chain_topology}= | chain
# CPU settings
| ${system_cpus}= | ${1}
| ${vpp_cpus}= | ${5}
| ${container_cpus}= | ${5}

*** Keywords ***
| Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | ...
| | [Arguments] | ${wt} | ${rxq} | ${framesize}
| | ...
| | # Test Variables required for test teardown
| | Set Test Variable | ${framesize}
| | Set Test Variable | ${rxq}
| | ${get_framesize}= | Get Frame Size | ${framesize}
| | ${max_rate}= | Calculate pps | ${s_limit}
| | ... | ${get_framesize} + ${srv6_overhead_3sids}
| | ...
| | Given Add '${wt}' worker threads and '${rxq}' rxqueues in 3-node single-link circular topology
| | And Add PCI devices to all DUTs
| | And Run Keyword If | ${get_framesize} + ${srv6_overhead_3sids} < ${1522}
| | ... | Add no multi seg to all DUTs
| | And Apply startup configuration on all VPP DUTs
| | When Initialize IPv6 forwarding over SRv6 with endpoint to SR-unaware Service Function via 'masquerading' behaviour in 3-node circular topology
| | Then Traffic should pass with maximum rate
| | ... | ${max_rate}pps | ${framesize} | ${traffic_profile}

*** Test Cases ***
| tc01-78B-1t1c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 1 phy core, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 78B frames using single trial\
| | ... | throughput test.
| | ...
| | [Tags] | 78B | 1C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=1 | rxq=1 | framesize=${78}

| tc02-1518B-1t1c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 1 phy core, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 1518B frames using single trial\
| | ... | throughput test.
| | ...
| | [Tags] | 1518B | 1C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=1 | rxq=1 | framesize=${1518}

| tc03-9000B-1t1c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 1 phy core, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 9000B frames using single trial\
| | ... | throughput test.
| | ...
| | [Tags] | 9000B | 1C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=1 | rxq=1 | framesize=${9000}

| tc04-IMIX-1t1c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 1 phy core, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for IMIX_v4_1 frames using single trial\
| | ... | throughput test.
| | ... | IMIX_v4_1 = (28x64B; 16x570B; 4x1518B)
| | ...
| | [Tags] | IMIX | 1C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=1 | rxq=1 | framesize=IMIX_v4_1

| tc05-78B-2t2c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 2 phy cores, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 78B frames using single trial\
| | ... | throughput test.
| | ...
| | [Tags] | 78B | 2C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=2 | rxq=1 | framesize=${78}

| tc06-1518B-2t2c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 2 phy cores, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 1518B frames using single trial\
| | ... | throughput test.
| | ...
| | [Tags] | 1518B | 2C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=2 | rxq=1 | framesize=${1518}

| tc07-9000B-2t2c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 2 phy cores, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 9000B frames using single trial\
| | ... | throughput test.
| | ...
| | [Tags] | 9000B | 2C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=2 | rxq=1 | framesize=${9000}

| tc08-IMIX-2t2c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 2 phy cores, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for IMIX_v4_1 frames using single trial\
| | ... | throughput test.
| | ... | IMIX_v4_1 = (28x64B; 16x570B; 4x1518B)
| | ...
| | [Tags] | IMIX | 2C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=2 | rxq=1 | framesize=IMIX_v4_1

| tc09-78B-4t4c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 4 phy cores, 2 receive queues per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 78B frames using single trial\
| | ... | throughput test.
| | ...
| | [Tags] | 78B | 4C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=4 | rxq=2 | framesize=${78}

| tc10-1518B-4t4c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 4 phy cores, 2 receive queues per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 1518B frames using single trial\
| | ... | throughput test.
| | ...
| | [Tags] | 1518B | 4C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=4 | rxq=2 | framesize=${1518}

| tc11-9000B-4t4c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 4 phy cores, 2 receive queues per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 9000B frames using single trial\
| | ... | throughput test.
| | ...
| | [Tags] | 9000B | 4C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=4 | rxq=2 | framesize=${9000}

| tc12-IMIX-4t4c-ethip6srhip6-ip6base-srv6proxy-masq-mrr
| | [Documentation]
| | ... | [Cfg] DUT runs IPv6 over SRv6 routing with masquerading SRv6 proxy\
| | ... | 4 phy cores, 2 receive queues per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for IMIX_v4_1 frames using single trial\
| | ... | throughput test.
| | ... | IMIX_v4_1 = (28x64B; 16x570B; 4x1518B)
| | ...
| | [Tags] | IMIX | 4C
| | ...
| | [Template] | Check RR for IPv6 routing over SRv6 with endpoint to SR-unaware Service Function via masquerading proxy behaviour
| | wt=4 | rxq=2 | framesize=IMIX_v4_1
