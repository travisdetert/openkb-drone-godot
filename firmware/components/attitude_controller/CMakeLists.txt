idf_component_register(
    SRCS "attitude_controller.c"
    INCLUDE_DIRS "include"
    REQUIRES pid_controller motor_mixer motor_output udp_comm esp_timer log
)
