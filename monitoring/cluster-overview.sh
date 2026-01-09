#!/bin/bash

# =============================================================================
# Kubernetes Cluster Overview Script  
# Erstellt von: Sebastian Meyer
# Zweck: Umfassende Übersicht über den MicroK8s Cluster Status
# =============================================================================

# Farben für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Header
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗"
echo -e "║                  🚀 KUBERNETES CLUSTER OVERVIEW              ║"
echo -e "║                    Sebastian Meyer's HA Cluster              ║" 
echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
echo

# 1. Cluster Nodes Status
echo -e "${PURPLE}📊 CLUSTER NODES STATUS${NC}"
echo -e "${PURPLE}========================${NC}"
microk8s kubectl get nodes -o wide
echo

# 2. NGINX Deployment Overview
echo -e "${BLUE}🚀 NGINX DEPLOYMENT OVERVIEW${NC}"
echo -e "${BLUE}=============================${NC}"
echo -e "${GREEN}Deployment Status:${NC}"
microk8s kubectl get deployment -l "app.kubernetes.io/name=nginx-website-chart"
echo
echo -e "${GREEN}NGINX Pod Distribution per Node:${NC}"
for node in $(microk8s kubectl get nodes --no-headers | awk '{print $1}'); do
    node_status=$(microk8s kubectl get node $node --no-headers | awk '{print $2}')
    pod_count=$(microk8s kubectl get pods -l "app.kubernetes.io/name=nginx-website-chart" -o wide --no-headers | grep $node | wc -l)
    
    if [ "$node_status" = "Ready" ]; then
        if [ $pod_count -gt 0 ]; then
            echo -e "  ${GREEN}✅ $node: $pod_count/2 NGINX Pods (Ready)${NC}"
        else
            echo -e "  ${YELLOW}⚠️  $node: $pod_count/2 NGINX Pods (Ready, aber keine Pods)${NC}"
        fi
    else
        if [ $pod_count -gt 0 ]; then
            echo -e "  ${RED}❌ $node: $pod_count/2 NGINX Pods (NotReady)${NC}"
        else
            echo -e "  ${RED}❌ $node: $pod_count/2 NGINX Pods (NotReady)${NC}"
        fi
    fi
done
echo

# 3. High-Availability Components Overview
echo -e "${PURPLE}⚖️ HIGH-AVAILABILITY COMPONENTS${NC}"
echo -e "${PURPLE}=================================${NC}"

# Master Components (Control Plane)
echo -e "${GREEN}Control Plane Distribution:${NC}"
for node in $(microk8s kubectl get nodes --no-headers | awk '{print $1}'); do
    node_status=$(microk8s kubectl get node $node --no-headers | awk '{print $2}')
    # Check if this node has control plane components
    if microk8s kubectl get pods -n kube-system -o wide --no-headers | grep -q $node; then
        if [ "$node_status" = "Ready" ]; then
            echo -e "  ${GREEN}✅ $node: Control Plane Active (Ready)${NC}"
        else
            echo -e "  ${RED}❌ $node: Control Plane (NotReady)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  $node: No Control Plane Components${NC}"
    fi
done
echo

# Ingress Controllers
echo -e "${GREEN}Ingress Controller Distribution:${NC}"
for node in $(microk8s kubectl get nodes --no-headers | awk '{print $1}'); do
    node_status=$(microk8s kubectl get node $node --no-headers | awk '{print $2}')
    ingress_count=$(microk8s kubectl get pods -n ingress -o wide --no-headers 2>/dev/null | grep $node | grep "Running" | wc -l || echo "0")
    ingress_total_node=$(microk8s kubectl get pods -n ingress -o wide --no-headers 2>/dev/null | grep $node | wc -l || echo "0")
    
    if [ $ingress_total_node -gt 0 ]; then
        if [ "$node_status" = "Ready" ] && [ $ingress_count -gt 0 ]; then
            echo -e "  ${GREEN}✅ $node: $ingress_count/1 Ingress Running (Ready)${NC}"
        elif [ "$node_status" = "Ready" ] && [ $ingress_count -eq 0 ]; then
            echo -e "  ${RED}❌ $node: $ingress_count/1 Ingress Running (Ready, aber Pod crashed)${NC}"
        else
            echo -e "  ${RED}❌ $node: $ingress_count/1 Ingress Running (NotReady)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  $node: Kein Ingress Controller${NC}"
    fi
done
echo

# MetalLB Load Balancer
echo -e "${GREEN}MetalLB Distribution:${NC}"
for node in $(microk8s kubectl get nodes --no-headers | awk '{print $1}'); do
    node_status=$(microk8s kubectl get node $node --no-headers | awk '{print $2}')
    speaker_count=$(microk8s kubectl get pods -n metallb-system -o wide --no-headers 2>/dev/null | grep $node | grep "speaker" | grep "Running" | wc -l || echo "0")
    speaker_total_node=$(microk8s kubectl get pods -n metallb-system -o wide --no-headers 2>/dev/null | grep $node | grep "speaker" | wc -l || echo "0")
    
    if [ $speaker_total_node -gt 0 ]; then
        if [ "$node_status" = "Ready" ] && [ $speaker_count -gt 0 ]; then
            echo -e "  ${GREEN}✅ $node: MetalLB Speaker Running (Ready)${NC}"
        elif [ "$node_status" = "Ready" ] && [ $speaker_count -eq 0 ]; then
            echo -e "  ${RED}❌ $node: MetalLB Speaker Failed (Ready, aber Pod crashed)${NC}"
        else
            echo -e "  ${RED}❌ $node: MetalLB Speaker (NotReady)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  $node: Kein MetalLB Speaker${NC}"
    fi
done

# MetalLB Controller
controller_status=$(microk8s kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep "controller" | grep "Running" | wc -l || echo "0")
if [ $controller_status -gt 0 ]; then
    echo -e "  ${GREEN}✅ MetalLB Controller: Running${NC}"
else
    echo -e "  ${RED}❌ MetalLB Controller: Not Running${NC}"
fi
echo

# 4. Services Overview
echo -e "${YELLOW}🌐 SERVICES OVERVIEW${NC}"
echo -e "${YELLOW}=====================${NC}"
microk8s kubectl get services -o wide
echo

# 5. Ingress Overview  
echo -e "${CYAN}🔗 INGRESS CONFIGURATION${NC}"
echo -e "${CYAN}=========================${NC}"
microk8s kubectl get ingress -o wide
echo

# 6. Resource Usage (if available)
echo -e "${PURPLE}📈 RESOURCE USAGE${NC}"
echo -e "${PURPLE}==================${NC}"
if microk8s kubectl top nodes >/dev/null 2>&1; then
    echo -e "${GREEN}Node Resources:${NC}"
    microk8s kubectl top nodes
    echo
    echo -e "${GREEN}Pod Resources (Top 10):${NC}"
    microk8s kubectl top pods -A --sort-by=cpu | head -11
else
    echo -e "${YELLOW}⚠️  Metrics not available (metrics-server not running)${NC}"
fi
echo

# 7. Quick Health Check
echo -e "${GREEN}✅ CLUSTER HEALTH SUMMARY${NC}" 
echo -e "${GREEN}===========================${NC}"
total_nodes=$(microk8s kubectl get nodes --no-headers | wc -l)
ready_nodes=$(microk8s kubectl get nodes --no-headers | grep " Ready " | wc -l)
total_nginx_pods=$(microk8s kubectl get pods -l "app.kubernetes.io/name=nginx-website-chart" --no-headers | grep "Running" | wc -l)
target_nginx_pods=6

# HA Component Counts - Dynamic based on DaemonSet configuration
running_ingress=$(microk8s kubectl get pods -n ingress --no-headers 2>/dev/null | grep "Running" | wc -l || echo "0")
desired_ingress=$(microk8s kubectl get daemonset -n ingress --no-headers 2>/dev/null | awk '{print $2}' || echo "3")
running_metallb=$(microk8s kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep "Running" | wc -l || echo "0")
desired_metallb_speakers=$(microk8s kubectl get daemonset -n metallb-system --no-headers 2>/dev/null | awk '{print $2}' | head -1 || echo "3")
desired_metallb=$((desired_metallb_speakers + 1))  # +1 for controller

echo -e "🖥️  Nodes: ${GREEN}$ready_nodes/$total_nodes Ready${NC}"
echo -e "🚀 NGINX Pods: ${GREEN}$total_nginx_pods/$target_nginx_pods Running${NC} (Soll: 2 pro Node)"
echo -e "🔗 Ingress Controllers: ${GREEN}$running_ingress/$desired_ingress Running${NC} (DaemonSet: 1 pro Node)"
echo -e "⚖️  MetalLB Components: ${GREEN}$running_metallb/$desired_metallb Running${NC} ($desired_metallb_speakers Speakers + 1 Controller)"
echo -e "🌐 Ingress LoadBalancer: $(microk8s kubectl get svc ingress-loadbalancer -n ingress --no-headers 2>/dev/null | awk '{print $4}' | grep -v '<none>' | wc -l)/1 Active"
echo -e "📋 Ingress Rules: $(microk8s kubectl get ingress --all-namespaces --no-headers | wc -l)/3 Configured"

# Website Test
echo
echo -e "${CYAN}🌍 WEBSITE CONNECTIVITY TEST${NC}"
echo -e "${CYAN}==============================${NC}"
LB_IP=$(microk8s kubectl get svc ingress-loadbalancer -n ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -n "$LB_IP" ] && [ "$LB_IP" != "null" ]; then
    # Test LoadBalancer connectivity (direct IP access will show 404 - this is expected)
    success=false
    response_code=""
    for attempt in 1 2 3; do
        response_code=$(curl -s --connect-timeout 3 --max-time 5 -o /dev/null -w "%{http_code}" http://$LB_IP 2>/dev/null || echo "000")
        if [ "$response_code" != "000" ] && [ "$response_code" != "" ]; then
            success=true
            break
        fi
        [ $attempt -lt 3 ] && sleep 1
    done
    
    if [ "$success" = true ]; then
        if [ "$response_code" = "404" ]; then
            echo -e "${GREEN}✅ Ingress LoadBalancer erreichbar: http://$LB_IP${NC}"
            echo -e "${CYAN}   📄 HTTP $response_code (erwartet bei direktem IP-Zugriff)${NC}"
            echo -e "${CYAN}   💡 Website nur über Domain erreichbar: sebastianmeyer.org${NC}"
        elif [ "$response_code" = "200" ]; then
            echo -e "${GREEN}✅ Website erreichbar unter: http://$LB_IP${NC}"
            echo -e "${GREEN}   📄 HTTP $response_code${NC}"
        else
            echo -e "${YELLOW}⚠️  Unerwartete Antwort: HTTP $response_code von http://$LB_IP${NC}"
        fi
        
        # Test with correct hostname if DNS resolves
        if nslookup sebastianmeyer.org >/dev/null 2>&1; then
            domain_test=$(curl -s --connect-timeout 3 --max-time 5 -o /dev/null -w "%{http_code}" -H "Host: sebastianmeyer.org" http://$LB_IP 2>/dev/null || echo "000")
            if [ "$domain_test" = "200" ]; then
                echo -e "${GREEN}   🌐 Domain-Test erfolgreich: sebastianmeyer.org → HTTP $domain_test${NC}"
            elif [ "$domain_test" != "000" ]; then
                echo -e "${YELLOW}   🌐 Domain-Test: sebastianmeyer.org → HTTP $domain_test${NC}"
            fi
        fi
    else
        echo -e "${RED}❌ Ingress LoadBalancer nicht erreichbar: http://$LB_IP${NC}"
        echo -e "${YELLOW}   🔍 Verbindungsprobleme zur LoadBalancer IP${NC}"
        # Show service status
        svc_status=$(microk8s kubectl get svc ingress-loadbalancer -n ingress --no-headers | awk '{print $4}')
        echo -e "${CYAN}   🔍 Ingress LoadBalancer External-IP: $svc_status${NC}"
    fi
else
    echo -e "${RED}❌ Ingress LoadBalancer IP nicht verfügbar${NC}"
fi

echo
echo -e "${CYAN}📋 TRAFFIC FLOW ARCHITEKTUR${NC}"
echo -e "${CYAN}============================${NC}"
echo -e "${GREEN}🌐 Korrekter Domain-basierter Traffic Flow:${NC}"
echo -e "${CYAN}   sebastianmeyer.org (DNS)${NC}"
echo -e "${CYAN}       ↓ Resolve to 192.168.1.71${NC}"
echo -e "${CYAN}   Ingress LoadBalancer (192.168.1.71)${NC}"
echo -e "${CYAN}       ↓ Host-Header: sebastianmeyer.org${NC}"
echo -e "${CYAN}   NGINX Ingress Controller${NC}"
echo -e "${CYAN}       ↓ Route based on hostname${NC}"
echo -e "${CYAN}   nginx-website Pod (ClusterIP)${NC}"
echo
echo -e "${GREEN}✅ Domain-Zugriff (sebastianmeyer.org):${NC}"
echo -e "${GREEN}   ✅ Host-Header vorhanden${NC}"

echo
echo -e "${CYAN}Script ausgeführt: $(date)${NC}"