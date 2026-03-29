idf_component_register(
    SRCS "main.c"
    INCLUDE_DIRS "."
    REQUIRES wifi_manager udp_comm attitude_controller motor_output status_led
             sensor_fusion
)
