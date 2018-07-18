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
| Force Tags | 3_NODE_SINGLE_LINK_TOPO | PERFTEST | HW_ENV | MRR
| ... | NIC_Intel-XL710 | ETH | L2BDMACLRN | BASE | VHOST | 2VM | VHOST_1024
| ...
| Suite Setup | Set up 3-node performance topology with DUT's NIC model
| ... | L2 | Intel-XL710
| Suite Teardown | Tear down 3-node performance topology
| ...
| Test Setup | Set up performance test
| Test Teardown | Tear down performance mrr test with vhost and VM with dpdk-testpmd
| ... | dut1_node=${dut1} | dut1_vm_refs=${dut1_vm_refs}
| ... | dut2_node=${dut2} | dut2_vm_refs=${dut2_vm_refs}
| ...
| Test Template | Local Template
| ...
| Documentation | *Raw results L2BD test cases with vhost*
| ...
| ... | *[Top] Network Topologies:* TG-DUT1-DUT2-TG 3-node circular topology
| ... | with single links between nodes.
| ... | *[Enc] Packet Encapsulations:* Eth-IPv4 for L2 switching of IPv4.
| ... | *[Cfg] DUT configuration:* DUT1 and DUT2 are configured with L2 bridge-
| ... | domain and MAC learning enabled. Qemu Guests are connected to VPP via
| ... | vhost-user interfaces. Guests are running DPDK testpmd interconnecting
| ... | vhost-user interfaces using 5 cores pinned to cpus on NUMA1 and 2048M
| ... | memory. Testpmd is using socket-mem=1024M (512x2M hugepages), 5 cores
| ... | (1 main core and 4 cores dedicated for io), forwarding mode is set to
| ... | io, rxd/txd=1024, burst=64. DUT1, DUT2 are tested with 2p40GE NIC XL710
| ... | by Intel.
| ... | *[Ver] TG verification:* In MaxReceivedRate test TG sends traffic
| ... | at line rate and reports total received/sent packets over trial period.
| ... | Test packets are generated by TG on links to DUTs. TG traffic profile
| ... | contains two L3 flow-groups (flow-group per direction, 253 flows per
| ... | flow-group) with all packets containing Ethernet header, IPv4 header
| ... | with IP protocol=61 and static payload. MAC addresses are matching MAC
| ... | addresses of the TG node interfaces.

*** Variables ***
| ${perf_qemu_qsz}= | 1024
# CPU settings
| ${system_cpus}= | ${1}
| ${vpp_cpus}= | ${5}
| ${vm_cpus}= | ${5}
# XL710-DA2 bandwidth limit ~49Gbps/2=24.5Gbps
| ${s_24.5G}= | ${24500000000}
# XL710-DA2 Mpps limit 37.5Mpps/2=18.75Mpps
| ${s_18.75Mpps}= | ${18750000}
# Traffic profile:
| ${traffic_profile}= | trex-sl-3n-ethip4-ip4src254

*** Keywords ***
| Local Template
| | [Documentation]
| | ... | [Cfg] DUT runs L2BD switching config.
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
| | [Arguments] | ${framesize} | ${phy_cores} | ${rxq}=${None}
| | ...
| | ${dut1_vm_refs}= | Create Dictionary
| | ${dut2_vm_refs}= | Create Dictionary
| | Set Test Variable | ${dut1_vm_refs}
| | Set Test Variable | ${dut2_vm_refs}
| | ...
| | Given Add worker threads and rxqueues to all DUTs | ${phy_cores} | ${rxq}
| | And Add PCI devices to all DUTs
| | ${max_rate} | ${jumbo} = | Get Max Rate And Jumbo And Handle Multi Seg
| | ... | ${s_24.5G} | ${framesize} | pps_limit=${s_18.75Mpps}
| | And Apply startup configuration on all VPP DUTs
| | When Initialize L2 bridge domains with Vhost-User for '2' VMs in 3-node circular topology
| | Set Test Variable | \${jumbo_frames} | ${jumbo}
| | And Configure '2' guest VMs with dpdk-testpmd connected via vhost-user in 3-node circular topology
| | Then Traffic should pass with maximum rate
| | ... | ${max_rate}pps | ${framesize} | ${traffic_profile}

*** Test Cases ***
| tc01-64B-1c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | 64B | 1C
| | framesize=${64} | phy_cores=${1}

| tc02-64B-2c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | 64B | 2C
| | framesize=${64} | phy_cores=${2}

| tc03-64B-4c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | 64B | 4C
| | framesize=${64} | phy_cores=${4}

| tc04-1518B-1c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | 1518B | 1C
| | framesize=${1518} | phy_cores=${1}

| tc05-1518B-2c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | 1518B | 2C
| | framesize=${1518} | phy_cores=${2}

| tc06-1518B-4c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | 1518B | 4C
| | framesize=${1518} | phy_cores=${4}

| tc07-9000B-1c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | 9000B | 1C
| | framesize=${9000} | phy_cores=${1}

| tc08-9000B-2c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | 9000B | 2C
| | framesize=${9000} | phy_cores=${2}

| tc09-9000B-4c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | 9000B | 4C
| | framesize=${9000} | phy_cores=${4}

| tc10-IMIX-1c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | IMIX | 1C
| | framesize=IMIX_v4_1 | phy_cores=${1}

| tc11-IMIX-2c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | IMIX | 2C
| | framesize=IMIX_v4_1 | phy_cores=${2}

| tc12-IMIX-4c-eth-l2bdbasemaclrn-eth-4vhostvr1024-2vm-mrr
| | [Tags] | IMIX | 4C
| | framesize=IMIX_v4_1 | phy_cores=${4}
