//
//  metrics.metal
//  metrics
//
//  Created by Evadne Wu on 02/01/2017.
//  Copyright © 2017 Radius Development. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexInput {
	float2 position;
	short3 color;
};

struct VertexOutput {
	float4 position [[position]];
	short3 color;
};

vertex VertexOutput vertex_main(device VertexInput *vertices [[buffer(0)]], uint vid [[vertex_id]]) {
	VertexInput vertexInput = vertices[vid];
	
	return (VertexOutput){
		(float4){
			vertexInput.position[0],
			vertexInput.position[1],
			0,
			1
		},
		vertexInput.color
	};
}

fragment float4 fragment_main(VertexOutput inVertex [[stage_in]]) {
	return (float4) {
		(float)inVertex.color[0]/255.0f,
		(float)inVertex.color[1]/255.0f,
		(float)inVertex.color[2]/255.0f,
		1
	};
}
