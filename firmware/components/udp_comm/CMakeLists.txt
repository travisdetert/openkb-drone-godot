idf_component_register(
    SRCS "udp_comm.c"
    INCLUDE_DIRS "include"
    REQUIRES lwip esp_timer log json wifi_manager binary_protocol
)
