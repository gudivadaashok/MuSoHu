#!/usr/bin/env python3

import os
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, GroupAction
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    """Launch all MuSoHu helmet sensors"""
    
    # Declare launch arguments
    launch_imu_arg = DeclareLaunchArgument(
        'launch_imu',
        default_value='true',
        description='Launch Witmotion IMU node'
    )
    
    launch_lidar_arg = DeclareLaunchArgument(
        'launch_lidar',
        default_value='true',
        description='Launch RoboSense LiDAR node'
    )
    
    launch_zed_arg = DeclareLaunchArgument(
        'launch_zed',
        default_value='true',
        description='Launch ZED camera node'
    )
    
    launch_audio_arg = DeclareLaunchArgument(
        'launch_audio',
        default_value='true',
        description='Launch ReSpeaker audio node'
    )
    
    # Get launch configurations
    launch_imu = LaunchConfiguration('launch_imu')
    launch_lidar = LaunchConfiguration('launch_lidar')
    launch_zed = LaunchConfiguration('launch_zed')
    launch_audio = LaunchConfiguration('launch_audio')
    
    # Get package directories
    helmet_bringup_dir = FindPackageShare('helmet_bringup')
    
    # IMU Launch
    imu_launch = GroupAction(
        condition=IfCondition(launch_imu),
        actions=[
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource([
                    PathJoinSubstitution([
                        helmet_bringup_dir,
                        'launch',
                        'imu.launch.py'
                    ])
                ])
            )
        ]
    )
    
    # LiDAR Launch
    lidar_launch = GroupAction(
        condition=IfCondition(launch_lidar),
        actions=[
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource([
                    PathJoinSubstitution([
                        helmet_bringup_dir,
                        'launch',
                        'lidar.launch.py'
                    ])
                ])
            )
        ]
    )
    
    # ZED Camera Launch
    zed_launch = GroupAction(
        condition=IfCondition(launch_zed),
        actions=[
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource([
                    PathJoinSubstitution([
                        helmet_bringup_dir,
                        'launch',
                        'zed.launch.py'
                    ])
                ])
            )
        ]
    )
    
    # Audio Launch
    audio_launch = GroupAction(
        condition=IfCondition(launch_audio),
        actions=[
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource([
                    PathJoinSubstitution([
                        helmet_bringup_dir,
                        'launch',
                        'audio.launch.py'
                    ])
                ])
            )
        ]
    )

    # Action Generator
    action_generator = Node(
        package='helmet_bringup',
        executable='action_generator.py',
        name='action_generator',
        output='screen'
    )
    
    return LaunchDescription([
        launch_imu_arg,
        launch_lidar_arg,
        launch_zed_arg,
        launch_audio_arg,
        imu_launch,
        lidar_launch,
        zed_launch,
        audio_launch,
        action_generator,
    ])