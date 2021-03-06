//
// Copyright (C) 2013 Michael Kirsche
// Copyright (C) 2008 Feng Chen
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program; if not, see <http://www.gnu.org/licenses/>.
//

// Application Layer
import inet.applications.IPingApp;
import inet.applications.ITCPApp;
import inet.applications.IUDPApp;

// Transport Layer
import inet.transport.tcp.TCP;
import inet.transport.IUDP;

// Internet
import inet.networklayer.ipv6.RoutingTable6;
import inet.nodes.ipv6.NetworkLayer6;
import inet.linklayer.IWiredNic;


// 802.15.4 MAC / Link Layer
import inet.wpan.linklayer.ieee802154.Ieee802154csmaNic;

// Additional Modules
import inet.networklayer.common.InterfaceTable;
import inet.base.NotificationBoard;
import inet.mobility.IMobility;
import inet.networklayer.IManetRouting;
import inet.battery.IBattery;
import inet.wpan.Isabel.Base.Display;

//
// \IPv6 host with TCP, UDP layers and applications.
//
module NodeEK
{
    parameters:
        @node();
        int numTcpApps = default(0);
        int numUdpApps = default(0);  // no of UDP apps. Specify the app types in INI file with udpApp[0..1].typename="UDPVideoStreamCli" syntax
        int numPingApps = default(0);  // no of PING apps -> Specify the app types in INI file with pingApp[0..1].typename="PingApp" syntax
        string udpType = default(firstAvailable("UDP","UDP_None"));
        // MANETRouting disabled because IPv6 nodes lacks MANET routing support
        //        string routingFile = default("");
        //        string routingProtocol @enum("AODVUU","DYMOUM","DYMO","DSRUU","OLSR","OLSR_ETX","DSDV_2","Batman") = default("");  // used mobile routing protocol. see: inet.networklayer.manetrouting
        string mobilityType;
        string batteryModel @enum("InetSimpleBattery","BasicBattery","") = default("InetSimpleBattery");
        xml routingTable = default(xml("<routingTable/>"));
        bool IPForward = default(true);
        @display("i=device/accesspoint;bgb=491,420");

    gates:
        input radioIn @directIn;
        inout ethg[] @labels(EtherFrame-conn);
        inout pppg[] @labels(PPPFrame-conn);

    submodules:
        notificationBoard: NotificationBoard {
            parameters:
                @display("p=60,51");
        }
        interfaceTable: InterfaceTable {
            parameters:
                @display("p=60,291");
        }
        routingTable6: RoutingTable6 {
            parameters:
                isRouter = true;
                forwardMulticast = true;
                routingTable = routingTable;
                @display("p=60,369");
        }
        tcpApp[numTcpApps]: <tcpAppType> like ITCPApp {
            parameters:
                @display("p=197,51;i=block/app");
        }
        tcp: TCP {
            parameters:
                @display("p=197,138;i=block/wheelbarrow");
        }
        //        udpApp[numUdpApps]: <udpAppType> like IUDPApp {
        //            parameters:
        //                @display("p=351,51;i=block/app");
        //        }
        udpApp[numUdpApps]: <> like IUDPApp {
            parameters:
                @display("p=351,51,row,60");
        }
        //        udp: UDP {
        //            parameters:
        //                @display("p=351,138;i=block/transport");
        //        }
        udp: <udpType> like IUDP if numUdpApps>0 {
            parameters:
                @display("p=351,138;i=block/transport");
        }
        pingApp[numPingApps]: <default("PingApp")> like IPingApp {
            parameters:
                @display("p=421,214");
        }
        networkLayer: NetworkLayer6 {
            parameters:
                @display("p=283,214;i=block/fork;q=queue");
            gates:
                ifIn[1];
                ifOut[1];
        }
        // MANETRouting disabled because IPv6 nodes lacks MANET routing support
        //        manetrouting: <routingProtocol> like IManetRouting if routingProtocol != "" {
        //            @display("p=159,287");
        //        }
        lrwpan: Ieee802154csmaNic {
            parameters:
                @display("p=200,330;q=queue;i=block/ifcard");
        }
        eth[sizeof(ethg)]: <default("EthernetInterface")> like IWiredNic {
            parameters:
                @display("p=283,330,row,90;q=txQueue");
        }
        ppp[sizeof(pppg)]: <default("PPPInterface")> like IWiredNic {
            parameters:
                @display("p=400,330,row,90;q=txQueue");
        }
        mobility: <mobilityType> like IMobility {
            parameters:
                @display("p=135,214;i=block/cogwheel");

        }
        disp: Display {
            parameters:
                @display("p=60,214;i=block/app2");

        }
        battery: <batteryModel> like IBattery if batteryModel != "" {
            parameters:
                @display("p=60,131;i=block/plug");

        }
    connections allowunconnected:
        for i=0..numTcpApps-1 {
            tcpApp[i].tcpOut --> tcp.appIn++;
            tcpApp[i].tcpIn <-- tcp.appOut++;
        }

        tcp.ipv6Out --> networkLayer.tcpIn;
        tcp.ipv6In <-- networkLayer.tcpOut;

//        for i=0..numUdpApps-1 {
//            udpApp[i].udpOut --> udp.appIn++;
//            udpApp[i].udpIn <-- udp.appOut++;
//        }
//
//        udp.ipv6Out --> networkLayer.udpIn;
//        udp.ipv6In <-- networkLayer.udpOut;

        for i=0..numUdpApps-1 {
            udpApp[i].udpOut --> udp.appIn++;
            udpApp[i].udpIn <-- udp.appOut++;
        }

        udp.ipv6Out --> networkLayer.udpIn if numUdpApps>0;
        udp.ipv6In <-- networkLayer.udpOut if numUdpApps>0;

        for i=0..numPingApps-1 {
            networkLayer.pingOut++ --> pingApp[i].pingv6In;
            networkLayer.pingIn++ <-- pingApp[i].pingv6Out;
        }

        // MANET routing support disabled because IPv6 does not support it at the moment
//      networkLayer.manetOut --> manetrouting.from_ip if routingProtocol != "";
//      networkLayer.manetIn <-- manetrouting.to_ip if routingProtocol != "";

        // connections to network outside
        radioIn --> lrwpan.radioIn;
        lrwpan.upperLayerOut --> networkLayer.ifIn[0];
        lrwpan.upperLayerIn <-- networkLayer.ifOut[0];

        for i=0..sizeof(ethg)-1 {
            ethg[i] <--> eth[i].phys;
            eth[i].upperLayerOut --> networkLayer.ifIn++;
            eth[i].upperLayerIn <-- networkLayer.ifOut++;
        }

        for i=0..sizeof(pppg)-1 {
            pppg[i] <--> ppp[i].phys;
            ppp[i].upperLayerOut --> networkLayer.ifIn++;
            ppp[i].upperLayerIn <-- networkLayer.ifOut++;
        }
}
