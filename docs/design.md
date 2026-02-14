# It Gets Deeper - Game Design Document

## 1. Overview
**Title:** It Gets Deeper
**Genre:** 3D Tunnel Flyer / Shooter
**Platform:** Windows
**Engine:** Godot 4

## 2. Core Gameplay
The player controls a fighter-jet-like ship flying continuously "down" a procedurally generated tunnel. The primary goal is to survive, dodge obstacles, and destroy enemy ships flying up towards the player.

### 2.1 Movement
- **Forward Motion:** Automatic and continuous at a fixed speed.
- **Steering:** Player uses input (likely WASD or Arrow Keys) to move the ship Up, Down, Left, and Right within the tunnel's cross-section.
- **Camera:** 3rd person perspective. The camera follows behind the player, staying generally above and to one side. It dynamically switches sides as the player moves to keep a clear view.

### 2.2 Combat
- **Weapons:** The ship can fire projectiles forward.
- **Ammunition:**
    - Finite usage (depletes when firing).
    - **Auto-Reload:** Starts immediately when empty, or after a short delay of not firing.
    - **Penalty:** Firing during reload incurs an ammo penalty (renders weapon unusable for longer, or reduces returned ammo? TBD: "ammo penalty" implies loss of ammo).
### 2.3 Environmental Hazards [NEW]
- **Crystals:** Sharp, jagged structures protruding from the tunnel walls. Generated via cellular noise.
- **Pipes & Poles:**
    - Vertical poles crossing the tunnel.
    - Horizontal pipes running along sides.
    - Serve as obstacles to dodge.

### 2.4 Enemies
- **Spawn:** Continuously ahead in NxM blocks.
- **Movement:** Sine wave patterns (Up/Down/Left/Right).
- **Size:** Large (2x scale).
- **Behavior:**
    - **No Shooting.**
    - **Collision:** Colliding with the player causes significant damage (20).
    - **Health:** Can be destroyed by player fire.

### 2.5 Collision & Health
- **Wall Collision:** Bounce off walls, speed penalty.
- **Enemy Collision:** Take damage, enemy dies.

### 2.6 UI / HUD
- **Position:** Top Left.
- **Elements:**
    - Damage Level (Health).
    - Score.
    - Ammunition Indicator.

### 2.7 Input & System
- **Controls:**
    - WASD/Arrows: Steer.
    - Space: Fire.
    - Escape: Quit Game immediately.

## 3. Technical Approach

### 3.1 Tunnel Generation
- **Algorithm:** Marching Cubes.
- **Data Source:**
    - **Tunnel:** Tube shape with Perlin noise.
    - **Crystals:** Cellular noise added to density.
    - **Obstructions:** CSG operations (Union) for pipes/poles.
- **Optimization:** Chunked generation.

### 3.2 Visualization (Shaders)
- **Depth Shader:** Custom shader that fades objects based on distance.
- **Depth-Based Color:** Brightness/intensity shifts based on depth.
- **No Culling:** To render inside-out/thin geometry correctly.

## 4. Assets
- **Meshes:** Procedural Tunnel, Player Ship, Enemy Ship.
- **Audio:** Sfx for shooting, engines, impacts.
