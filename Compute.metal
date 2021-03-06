//
//  File.metal
//  Geosphere
//
//  Created by Jacob Martin on 4/17/17.
//  Copyright © 2017 Jacob Martin. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void deformNormal(const device float3 *inVerts [[ buffer(0) ]],
                         device float3 *outVerts [[ buffer(1) ]],
                         device float3 *outNormals [[ buffer(2) ]],
                         uint id [[ thread_position_in_grid ]])
{
    
    if (id % 3 == 0) {
        
        const float3 v1 = inVerts[id];
        const float3 v2 = inVerts[id + 1];
        const float3 v3 = inVerts[id + 2];
        
        const float3 v12 = v2 - v1;
        const float3 v13 = v3 - v1;
        
        const float3 normal = fast::normalize(cross(v12, v13));
        
        outVerts[id] = v1;
        outVerts[id + 1] = v2;
        outVerts[id + 2] = v3;
        
        outNormals[id] = normal;
        outNormals[id + 1] = normal;
        outNormals[id + 2] = normal;
    }
}


struct DeformData {
    float3 location;
};





static float3 mod289(float3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

static float2 mod289(float2 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

static float3 permute(float3 x) {
    return mod289(((x*34.0)+1.0)*x);
}

static float snoise(float2 v)
{
    const float4 C = float4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                            0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                            -0.577350269189626,  // -1.0 + 2.0 * C.x
                            0.024390243902439); // 1.0 / 41.0
    // First corner
    float2 i  = floor(v + dot(v, C.yy) );
    float2 x0 = v -   i + dot(i, C.xx);
    
    // Other corners
    float2 i1;
    //i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
    //i1.y = 1.0 - i1.x;
    i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    // x0 = x0 - 0.0 + 0.0 * C.xx ;
    // x1 = x0 - i1 + 1.0 * C.xx ;
    // x2 = x0 - 1.0 + 2.0 * C.xx ;
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    
    // Permutations
    i = mod289(i); // Avoid truncation effects in permutation
    float3 p = permute( permute( i.y + float3(0.0, i1.y, 1.0 ))
                       + i.x + float3(0.0, i1.x, 1.0 ));
    
    float3 m = max(0.5 - float3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;
    
    // Gradients: 41 points uniformly over a line, mapped onto a diamond.
    // The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)
    
    float3 x = 2.0 * fract(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;
    
    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt( a0*a0 + h*h );
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
    
    // Compute final noise value at P
    float3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

static float noisy(float2 x) {
    return snoise(float2(snoise(x),snoise(x)));
}

kernel void deformVertexNoise(const device float3 *inVerts [[ buffer(0) ]],
                              device float3 *outVerts [[ buffer(1) ]],
                              constant DeformData &deformD [[ buffer(2)]],
                              uint id [[ thread_position_in_grid ]])
{
    
    
    const float3 inVert = inVerts[id];
    
    
    
    //    const float3 outVert = float3(inVert.x,noisy(((inVert.xy*inVert.yz)/30.0*cos(deformD.location.x))+deformD.location.x),inVert.z);
    const float3 outVert = float3(inVert.x,inVert.y,inVert.z);
    
    outVerts[id] = outVert;
}

