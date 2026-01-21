#!/usr/bin/env python3

import os
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    """Launch ZED camera node"""
    
    # Declare launch arguments
    camera_model_arg = DeclareLaunchArgument(
        'camera_model',
        default_value='zed2i',
        description='ZED camera model (zed, zed2, zed2i, zedm, zedx, zedxm)'
    )
    
    camera_name_arg = DeclareLaunchArgument(
        'camera_name',
        default_value='zed2i',
        description='Camera name for topics'
    )
    
    # Get launch configurations
    camera_model = LaunchConfiguration('camera_model')
    camera_name = LaunchConfiguration('camera_name')
    
    # Get package directories
    zed_wrapper_dir = FindPackageShare('zed_wrapper')
    helmet_bringup_dir = FindPackageShare('helmet_bringup')
    
    # ZED launch
    zed_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([
            PathJoinSubstitution([
                zed_wrapper_dir,
                'launch',
                'zed_camera.launch.py'
            ])
        ]),
        launch_arguments={
            'camera_model': camera_model,
            'camera_name': camera_name,
            'config_path': PathJoinSubstitution([
                helmet_bringup_dir,
                'config',
                'zed_params.yaml'
            ])
        }.items()
    )
    
    return LaunchDescription([
        camera_model_arg,
        camera_name_arg,
        zed_launch,
    ])