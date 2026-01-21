#!/usr/bin/env python3

import os
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    """Launch Witmotion IMU node"""
    
    # Declare launch arguments
    device_arg = DeclareLaunchArgument(
        'device',
        default_value='/dev/ttyUSB0',
        description='Serial device for IMU'
    )
    
    frame_id_arg = DeclareLaunchArgument(
        'frame_id',
        default_value='imu_link',
        description='Frame ID for IMU data'
    )
    
    baud_arg = DeclareLaunchArgument(
        'baud',
        default_value='9600',
        description='Serial baud rate'
    )
    
    # Get launch configurations
    device = LaunchConfiguration('device')
    frame_id = LaunchConfiguration('frame_id')
    baud = LaunchConfiguration('baud')
    
    ##################################################
    # TODO: fix to use a config file imu_params.yaml
    ##################################################

    # IMU node - using direct parameters instead of config file
    imu_node = Node(
        package='witmotion_ros2',
        executable='witmotion_ros2',
        name='imu_node',
        parameters=[{
            'port': device,
            'baud': baud,
            'frame_id': frame_id,
            'rate': 10.0,
        }],
        output='screen'
    )
    
    return LaunchDescription([
        device_arg,
        frame_id_arg,
        baud_arg,
        imu_node,
    ])