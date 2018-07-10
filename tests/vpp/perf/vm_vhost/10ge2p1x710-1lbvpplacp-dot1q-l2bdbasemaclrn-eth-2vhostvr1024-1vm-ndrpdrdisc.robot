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
| Library | resources.libraries.python.QemuUtils
| ...
| Force Tags | 3_NODE_SINGLE_LINK_TOPO | PERFTEST | HW_ENV | NDRPDRDISC
| ... | NIC_Intel-X710 | DOT1Q | L2BDMACLRN | BASE | VHOST | VM
| ... | VHOST_1024 | LBOND | LBOND_VPP| LBOND_MODE_LACP | LBOND_LB_L34
| ...
| Suite Setup | Run Keywords
| ... | Set up 3-node performance topology with DUT's NIC model | L2
| ... | Intel-X520-DA2
| ... | AND | Set up performance test suite with LACP mode link bonding
| ...
| Suite Teardown | Tear down 3-node performance topology
| ...
| Test Setup | Set up performance test
| Test Teardown | Tear down performance test with vhost and VM with dpdk-testpmd
| ... | ${min_rate}pps | ${framesize} | ${traffic_profile}
| ... | dut1_node=${dut1} | dut1_vm_refs=${dut1_vm_refs}
| ... | dut2_node=${dut2} | dut2_vm_refs=${dut2_vm_refs}
| ...
| Test Template | Local template
| ...
| Documentation | *RFC2544: Packet throughput L2BD test cases with vhost and
| ... | vpp link bonding*
| ...
| ... | *[Top] Network Topologies:* TG-DUT1-DUT2-TG 3-node circular topology
| ... | with single links between nodes.
| ... | *[Enc] Packet Encapsulations:* Eth-IPv4 for L2 switching of IPv4. 802.1q
| ... | tagging is applied on link between DUT1 and DUT2.
| ... | *[Cfg] DUT configuration:* DUT1 and DUT2 are configured with VPP
| ... | link bonding (mode LACP, transmit policy l34) on link between DUT1 and
| ... | DUT2 and L2 bridge-domain with MAC learning enabled. Qemu Guest is
| ... | connected to VPP via vhost-user interfaces. Guest is running DPDK
| ... | testpmd interconnecting vhost-user interfaces using 5 cores pinned to
| ... | cpus 5-9 and 2048M memory. Testpmd is using socket-mem=1024M (512x2M
| ... | hugepages), 5 cores (1 main core and 4 cores dedicated for io),
| ... | forwarding mode is set to io, rxd/txd=1024, burst=64. DUT1, DUT2 are
| ... | tested with 2p10GE NIC X710 Fortville by Intel.
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
| ${perf_qemu_qsz}= | 1024
| ${subid}= | 10
| ${tag_rewrite}= | pop-1
| ${vlan_overhead}= | ${4}
# Link bonding config
| ${bond_mode}= | lacp
| ${lb_mode}= | l34
# X710 bandwidth limit
| ${s_limit} | ${10000000000}
# Socket names
| ${bd_id1}= | 1
| ${bd_id2}= | 2
| ${sock1}= | /tmp/sock-1-${bd_id1}
| ${sock2}= | /tmp/sock-1-${bd_id2}
# Traffic profile:
| ${traffic_profile}= | trex-sl-3n-ethip4-ip4src254

*** Keywords ***
| Local template
| | [Arguments] | ${phy_cores} | ${framesize} | ${search_type} | ${rxq}=${None}
| | ... | ${min_rate}=${10000}
| | ...
| | Set Test Variable | ${framesize}
| | Set Test Variable | ${min_rate}
| | ${get_framesize}= | Get Frame Size | ${framesize}
| | ${max_rate}= | Calculate pps | ${s_limit}
| | ... | ${get_framesize + ${vlan_overhead}}
| | ${binary_min}= | Set Variable | ${min_rate}
| | ${binary_max}= | Set Variable | ${max_rate}
| | ${threshold}= | Set Variable | ${min_rate}
| | ${dut1_vm_refs}= | Create Dictionary
| | ${dut2_vm_refs}= | Create Dictionary
| | Set Test Variable | ${dut1_vm_refs}
| | Set Test Variable | ${dut2_vm_refs}
| | ${jumbo_frames}= | Set Variable If
| | ... | ${get_framesize + ${vlan_overhead}} < ${1522} | ${False} | ${True}
| | ...
| | Given Add worker threads and rxqueues to all DUTs | ${phy_cores} | ${rxq}
| | And Add PCI devices to all DUTs
| | And Add VLAN Strip Offload switch off between DUTs in 3-node single link topology
| | And Run Keyword If | ${get_framesize + ${vlan_overhead}} < ${1522}
| | ... | Add no multi seg to all DUTs
| | And Apply startup configuration on all VPP DUTs
| | When Initialize L2 bridge domains with Vhost-User and VLAN with VPP link bonding in a 3-node circular topology
| | ... | ${bd_id1} | ${bd_id2} | ${sock1} | ${sock2} | ${subid}
| | ... | ${tag_rewrite} | ${bond_mode} | ${lb_mode}
| | ${vm1}= | And Configure guest VM with dpdk-testpmd connected via vhost-user
| | ... | ${dut1} | ${sock1} | ${sock2} | DUT1_VM1
| | ... | jumbo_frames=${jumbo_frames}
| | And Set To Dictionary | ${dut1_vm_refs} | DUT1_VM1 | ${vm1}
| | ${vm2}= | And Configure guest VM with dpdk-testpmd connected via vhost-user
| | ... | ${dut2} | ${sock1} | ${sock2} | DUT2_VM1
| | ... | jumbo_frames=${jumbo_frames}
| | And Set To Dictionary | ${dut2_vm_refs} | DUT2_VM1 | ${vm2}
| | And All Vpp Interfaces Ready Wait | ${nodes}
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
| tc01-64B-1t1c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | 64B | 1C | NDRDISC
| | phy_cores=${1} | framesize=${64} | search_type=NDR

| tc02-64B-1t1c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | 64B | 1C | PDRDISC | SKIP_PATCH
| | phy_cores=${1} | framesize=${64} | search_type=PDR

| tc03-1518B-1t1c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | 1518B | 1C | NDRDISC
| | phy_cores=${1} | framesize=${1518} | search_type=NDR

| tc04-1518B-1t1c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | 1518B | 1C | PDRDISC | SKIP_PATCH
| | phy_cores=${1} | framesize=${1518} | search_type=PDR

| tc05-9000B-1t1c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | 9000B | 1C | NDRDISC
| | phy_cores=${1} | framesize=${9000} | search_type=NDR

| tc06-9000B-1t1c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | 9000B | 1C | PDRDISC | SKIP_PATCH
| | phy_cores=${1} | framesize=${9000} | search_type=PDR

| tc07-IMIX-1t1c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | IMIX | 1C | NDRDISC
| | phy_cores=${1} | framesize=IMIX_v4_1 | search_type=NDR

| tc08-IMIX-1t1c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | IMIX | 1C | PDRDISC | SKIP_PATCH
| | phy_cores=${1} | framesize=IMIX_v4_1 | search_type=PDR

| tc09-64B-2t2c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | 64B | 2C | NDRDISC
| | phy_cores=${2} | framesize=${64} | search_type=NDR

| tc10-64B-2t2c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | 64B | 2C | PDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${64} | search_type=PDR

| tc11-1518B-2t2c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | 1518B | 2C | NDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${1518} | search_type=NDR

| tc12-1518B-2t2c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | 1518B | 2C | PDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${1518} | search_type=PDR

| tc13-9000B-2t2c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | 9000B | 2C | NDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${9000} | search_type=NDR

| tc14-9000B-2t2c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | 9000B | 2C | PDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=${9000} | search_type=PDR

| tc15-IMIX-2t2c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | IMIX | 2C | NDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=IMIX_v4_1 | search_type=NDR

| tc16-IMIX-2t2c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | IMIX | 2C | PDRDISC | SKIP_PATCH
| | phy_cores=${2} | framesize=IMIX_v4_1 | search_type=PDR

| tc17-64B-4t4c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | 64B | 4C | NDRDISC
| | phy_cores=${4} | framesize=${64} | search_type=NDR

| tc18-64B-4t4c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | 64B | 4C | PDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${64} | search_type=PDR

| tc19-1518B-4t4c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | 1518B | 4C | NDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${1518} | search_type=NDR

| tc20-1518B-4t4c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | 1518B | 4C | PDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${1518} | search_type=PDR

| tc21-9000B-4t4c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | 9000B | 4C | NDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${9000} | search_type=NDR

| tc22-9000B-4t4c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | 9000B | 4C | PDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=${9000} | search_type=PDR

| tc23-IMIX-4t4c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-ndrdisc
| | [Tags] | IMIX | 4C | NDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=IMIX_v4_1 | search_type=NDR

| tc24-IMIX-4t4c-1lbvpplacp-dot1q-l2bdbasemaclrn-eth-2vhostvr1024-1vm-pdrdisc
| | [Tags] | IMIX | 4C | PDRDISC | SKIP_PATCH
| | phy_cores=${4} | framesize=IMIX_v4_1 | search_type=PDR
