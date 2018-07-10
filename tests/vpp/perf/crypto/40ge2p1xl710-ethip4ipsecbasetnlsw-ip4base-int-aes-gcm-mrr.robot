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
| Resource | resources/libraries/robot/crypto/ipsec.robot
| ...
| Force Tags | 3_NODE_SINGLE_LINK_TOPO | PERFTEST | HW_ENV | MRR
| ... | IP4FWD | IPSEC | IPSECSW | IPSECTUN | NIC_Intel-XL710 | BASE
| ...
| Suite Setup | Set up IPSec performance test suite | L3 | Intel-XL710
| ... | SW_cryptodev
| Suite Teardown | Tear down 3-node performance topology
| ...
| Test Setup | Set up performance test
| Test Teardown | Tear down performance mrr test
| ...
| Documentation | *Raw results IPv4 IPsec tunnel mode performance test suite.*
| ...
| ... | *[Top] Network Topologies:* TG-DUT1-DUT2-TG 3-node circular topology
| ... | with single links between nodes.
| ... | *[Enc] Packet Encapsulations:* Eth-IPv4 on TG-DUTn,
| ... | Eth-IPv4-IPSec on DUT1-DUT2
| ... | *[Cfg] DUT configuration:* DUT1 and DUT2 are configured with DPDK SW
| ... | crypto devices and multiple IPsec tunnels between them.
| ... | DUTs get IPv4 traffic from TG, encrypt it
| ... | and send to another DUT, where packets are decrypted and sent back to TG
| ... | *[Ver] TG verification:* In MaxReceivedRate test TG sends traffic
| ... | at line rate and reports total received/sent packets over trial period.
| ... | Test packets are generated by TG on
| ... | links to DUTs. TG traffic profile contains two L3 flow-groups
| ... | (flow-group per direction, number of flows per flow-group equals to
| ... | number of IPSec tunnels) with all packets
| ... | containing Ethernet header, IPv4 header with IP protocol=61 and
| ... | static payload. MAC addresses are matching MAC addresses of the TG
| ... | node interfaces. Incrementing of IP.dst (IPv4 destination address) field
| ... | is applied to both streams.
| ... | *[Ref] Applicable standard specifications:* RFC4303 and RFC2544.

*** Variables ***
# XL710-DA2 bandwidth limit ~49Gbps/2=24.5Gbps
| ${s_24.5G}= | ${24500000000}
# XL710-DA2 Mpps limit 37.5Mpps/2=18.75Mpps
| ${s_18.75Mpps}= | ${18750000}
| ${tg_if1_ip4}= | 192.168.10.2
| ${dut1_if1_ip4}= | 192.168.10.1
| ${dut1_if2_ip4}= | 172.168.1.1
| ${dut2_if1_ip4}= | 172.168.1.2
| ${dut2_if2_ip4}= | 192.168.20.1
| ${tg_if2_ip4}= | 192.168.20.2
| ${raddr_ip4}= | 20.0.0.0
| ${laddr_ip4}= | 10.0.0.0
| ${addr_range}= | ${32}
| ${ipsec_overhead}= | ${54}
| ${n_tunnels}= | ${1}
# Traffic profile:
| ${traffic_profile}= | trex-sl-3n-ethip4-ip4dst${n_tunnels}

*** Keywords ***
| Check RR for IPv4 routing with IPSec SW cryptodev
| | [Documentation]
| | ... | [Cfg] DUT runs IPSec tunneling AES GCM config with ${wt} thread(s),\
| | ... | ${wt} phy core(s), ${rxq} receive queue(s) per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for ${framesize} frames using single\
| | ... | trial throughput test.
| | ...
| | [Arguments] | ${framesize} | ${wt} | ${rxq}
| | ...
| | # Test Variables required for test teardown
| | Set Test Variable | ${framesize}
| | ${get_framesize}= | Get Frame Size | ${framesize}
| | ${max_rate}= | Calculate pps | ${s_24.5G}
| | ... | ${get_framesize} + ${ipsec_overhead}
| | ${max_rate}= | Set Variable If
| | ... | ${max_rate} > ${s_18.75Mpps} | ${s_18.75Mpps} | ${max_rate}
| | ${encr_alg}= | Crypto Alg AES GCM 128
| | ${auth_alg}= | Integ Alg AES GCM 128
| | ...
| | Given Add '${wt}' worker threads and '${rxq}' rxqueues in 3-node single-link circular topology
| | And Add PCI devices to all DUTs
| | And Run Keyword If | ${get_framesize} < ${1522}
| | ... | Add no multi seg to all DUTs
| | And Add DPDK SW cryptodev on DUTs in 3-node single-link circular topology
| | ... | aesni_gcm | ${${wt}}
| | And Add DPDK dev default RXD to all DUTs | 2048
| | And Add DPDK dev default TXD to all DUTs | 2048
| | And Apply startup configuration on all VPP DUTs
| | When Generate keys for IPSec | ${encr_alg} | ${auth_alg}
| | And Initialize IPSec in 3-node circular topology
| | And VPP IPsec Create Tunnel Interfaces
| | ... | ${dut1} | ${dut2} | ${dut1_if2_ip4} | ${dut2_if1_ip4} | ${dut1_if2}
| | ... | ${dut2_if1} | ${n_tunnels} | ${encr_alg} | ${encr_key} | ${auth_alg}
| | ... | ${auth_key} | ${laddr_ip4} | ${raddr_ip4} | ${addr_range}
| | And Set interfaces in path in 3-node circular topology up
| | Then Traffic should pass with maximum rate
| | ... | ${max_rate}pps | ${framesize} | ${traffic_profile}

*** Test Cases ***
| tc01-64B-1t1c-ethip4ipsecbasetnlsw-ip4base-int-aes-gcm-mrr
| | [Documentation]
| | ... | [Cfg] DUTs run 1 IPsec tunnel AES GCM in each direction, configured\
| | ... | with 1 phy core, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 64B frames using single trial\
| | ... | throughput test.
| | [Tags] | 64B | 1C
| | ...
| | [Template] | Check RR for IPv4 routing with IPSec SW cryptodev
| | framesize=${64} | wt=1 | rxq=1

| tc02-1518B-1t1c-ethip4ipsecbasetnlsw-ip4base-int-aes-gcm-mrr
| | [Documentation]
| | ... | [Cfg] DUTs run 1 IPsec tunnel AES GCM in each direction, configured\
| | ... | with 1 phy core, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 1518B frames using single\
| | ... | trial throughput test.
| | [Tags] | 1518B | 1C
| | ...
| | [Template] | Check RR for IPv4 routing with IPSec SW cryptodev
| | framesize=${1518} | wt=1 | rxq=1

# TODO: Add check to make test fail if rx=0.
# TODO: Add 9000B test cases when they start passing.

| tc04-IMIX-1t1c-ethip4ipsecbasetnlsw-ip4base-int-aes-gcm-mrr
| | [Documentation]
| | ... | [Cfg] DUTs run 1 IPsec tunnel AES GCM in each direction, configured\
| | ... | with 1 phy core, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for IMIX_v4_1 frames using single\
| | ... | trial throughput test.
| | ... | IMIX_v4_1 = (28x64B; 16x570B; 4x1518B)
| | [Tags] | IMIX | 1C
| | ...
| | [Template] | Check RR for IPv4 routing with IPSec SW cryptodev
| | framesize=IMIX_v4_1 | wt=1 | rxq=1

| tc05-64B-2t2c-ethip4ipsecbasetnlsw-ip4base-int-aes-gcm-mrr
| | [Documentation]
| | ... | [Cfg] DUTs run 1 IPsec tunnel AES GCM in each direction, configured\
| | ... | with 2 phy cores, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 64B frames using single trial\
| | ... | throughput test.
| | [Tags] | 64B | 2C
| | ...
| | [Template] | Check RR for IPv4 routing with IPSec SW cryptodev
| | framesize=${64} | wt=2 | rxq=1

| tc06-1518B-2t2c-ethip4ipsecbasetnlsw-ip4base-int-aes-gcm-mrr
| | [Documentation]
| | ... | [Cfg] DUTs run 1 IPsec tunnel AES GCM in each direction, configured\
| | ... | with 2 phy cores, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 1518B frames using single\
| | ... | trial throughput test.
| | [Tags] | 1518B | 2C
| | ...
| | [Template] | Check RR for IPv4 routing with IPSec SW cryptodev
| | framesize=${1518} | wt=2 | rxq=1

| tc08-IMIX-2t2c-ethip4ipsecbasetnlsw-ip4base-int-aes-gcm-mrr
| | [Documentation]
| | ... | [Cfg] DUTs run 1 IPsec tunnel AES GCM in each direction, configured\
| | ... | with 2 phy cores, 1 receive queue per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for IMIX_v4_1 frames using single\
| | ... | trial throughput test.
| | ... | IMIX_v4_1 = (28x64B; 16x570B; 4x1518B)
| | [Tags] | IMIX | 2C
| | ...
| | [Template] | Check RR for IPv4 routing with IPSec SW cryptodev
| | framesize=IMIX_v4_1 | wt=2 | rxq=1

| tc09-64B-4t4c-ethip4ipsecbasetnlsw-ip4base-int-aes-gcm-mrr
| | [Documentation]
| | ... | [Cfg] DUTs run 1 IPsec tunnel AES GCM in each direction, configured\
| | ... | with 4 phy cores, 2 receive queues per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 64B frames using single trial\
| | ... | throughput test.
| | [Tags] | 64B | 4C
| | ...
| | [Template] | Check RR for IPv4 routing with IPSec SW cryptodev
| | framesize=${64} | wt=4 | rxq=2

| tc10-1518B-4t4c-ethip4ipsecbasetnlsw-ip4base-int-aes-gcm-mrr
| | [Documentation]
| | ... | [Cfg] DUTs run 1 IPsec tunnel AES GCM in each direction, configured\
| | ... | with 4 phy cores, 2 receive queues per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for 1518B frames using single\
| | ... | trial throughput test.
| | [Tags] | 1518B | 4C
| | ...
| | [Template] | Check RR for IPv4 routing with IPSec SW cryptodev
| | framesize=${1518} | wt=4 | rxq=2

| tc12-IMIX-4t4c-ethip4ipsecbasetnlsw-ip4base-int-aes-gcm-mrr
| | [Documentation]
| | ... | [Cfg] DUTs run 1 IPsec tunnel AES GCM in each direction, configured\
| | ... | with 4 phy cores, 2 receive queues per NIC port.
| | ... | [Ver] Measure MaxReceivedRate for IMIX_v4_1 frames using single\
| | ... | trial throughput test.
| | ... | IMIX_v4_1 = (28x64B; 16x570B; 4x1518B)
| | [Tags] | IMIX | 4C
| | ...
| | [Template] | Check RR for IPv4 routing with IPSec SW cryptodev
| | framesize=IMIX_v4_1 | wt=4 | rxq=2
