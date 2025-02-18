#!/usr/bin/awk -f
# metrics.awk
#
# Usage :
#   awk -v scenario=reno -f metrics.awk results/reno/trace-reno.tr
#   awk -v scenario=vegas -f metrics.awk results/vegas/trace-vegas.tr
#   awk -v scenario=mixed -f metrics.awk results/mixed/trace-mixed.tr
#
# Génère 3 fichiers dans graphs/ :
#   throughput-<scenario>.dat
#   latency-<scenario>.dat
#   loss-<scenario>.dat
#

BEGIN {
    # On peut ajuster l'intervalle ici si nécessaire.
    interval = 1.0
    next_interval = interval

    # Si la variable scenario n'est pas fournie, on met un nom par défaut.
    if (scenario == "") {
        scenario = "default"
    }

    # Prépare les chemins de sortie dans le dossier "graphs/"
    throughput_file = "graphs/throughput-" scenario ".dat"
    latency_file    = "graphs/latency-" scenario ".dat"
    loss_file       = "graphs/loss-" scenario ".dat"

    # Pour éviter d'appender aux anciens fichiers, on les supprime d'abord
    system("rm -f " throughput_file)
    system("rm -f " latency_file)
    system("rm -f " loss_file)

    # Variables de cumul
    total_bytes = 0
    total_delay = 0
    count_delay = 0
    sent_packets = 0
    received_packets = 0
}

{
    # $2 = temps (s)
    # $6 = taille du paquet en octets
    # $7 = temps d'envoi (à adapter selon votre format de trace)
    t = $2 + 0

    # Comptage des envois et réceptions
    if ($1 == "s") {
        sent_packets++
    } else if ($1 == "r") {
        received_packets++
        pkt_size = $6 + 0
        total_bytes += pkt_size

        # Calcul de la latence si le champ 7 correspond au temps d'envoi
        t_send = $7 + 0
        delay = t - t_send
        total_delay += delay
        count_delay++
    }

    # Dès qu'on dépasse l'intervalle courant, on calcule les métriques
    while (t > next_interval) {
        throughput = (total_bytes * 8) / interval  # bps
        avg_delay  = (count_delay > 0) ? (total_delay / count_delay) : 0
        loss_rate  = (sent_packets > 0) ? ((sent_packets - received_packets) / sent_packets * 100) : 0

        # Écriture dans les fichiers de sortie
        printf "%.2f %.2f\n", next_interval, throughput >> throughput_file
        printf "%.2f %.4f\n", next_interval, avg_delay  >> latency_file
        printf "%.2f %.2f\n", next_interval, loss_rate  >> loss_file

        # Réinitialisation pour l'intervalle suivant
        total_bytes = 0
        total_delay = 0
        count_delay = 0
        sent_packets = 0
        received_packets = 0
        next_interval += interval
    }
}

END {
    # Calcul pour le dernier intervalle restant
    throughput = (total_bytes * 8) / interval
    avg_delay  = (count_delay > 0) ? (total_delay / count_delay) : 0
    loss_rate  = (sent_packets > 0) ? ((sent_packets - received_packets) / sent_packets * 100) : 0

    printf "%.2f %.2f\n", next_interval, throughput >> throughput_file
    printf "%.2f %.4f\n", next_interval, avg_delay  >> latency_file
    printf "%.2f %.2f\n", next_interval, loss_rate  >> loss_file
}

