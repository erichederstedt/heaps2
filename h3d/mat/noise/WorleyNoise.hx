package h3d.mat.noise;

class WorleyNoise {

	public static function generate(texRes : Int = 64, gridSize : Int = 5, seed : Int = 0) {

		var points = [];
		var ratio = gridSize / texRes;

		var rnd = new hxd.Rand(seed);
		for ( k in 0...gridSize ) {
			for ( j in 0...gridSize ) {
				for ( i in 0...gridSize ) {
					var p = new h3d.col.Point(rnd.rand(), rnd.rand(), rnd.rand());
					p.scale(1.0 / gridSize);
					p.x += i / gridSize;
					p.y += j / gridSize;
					p.z += k / gridSize;
					points.push(p);
				}
			}
		}

		inline function getPointTiling(idx : h3d.col.IPoint) {
			var pointOffset = new h3d.col.Point();
			if ( idx.x < 0 ) {
				idx.x = gridSize - 1;
				pointOffset.x -= 1.0;
			}
			if ( idx.y < 0 ) {
				idx.y = gridSize - 1;
				pointOffset.y -= 1.0;
			}
			if ( idx.z < 0 ) {
				idx.z = gridSize - 1;
				pointOffset.z -= 1.0;
			}
			if ( idx.x >= gridSize ) {
				idx.x = 0;
				pointOffset.x += 1.0;
			}
			if ( idx.y >= gridSize ) {
				idx.y = 0;
				pointOffset.y += 1.0;
			}
			if ( idx.z >= gridSize ) {
				idx.z = 0;
				pointOffset.z += 1.0;
			}
			return points[idx.x + idx.y * gridSize + idx.z * gridSize * gridSize].add(pointOffset);
		}

		var offsets : Array<h3d.col.IPoint> = [
			new h3d.col.IPoint(-1, 0, 0), new h3d.col.IPoint(1, 0, 0),
			new h3d.col.IPoint(0, -1, 0), new h3d.col.IPoint(0, 1, 0),
			new h3d.col.IPoint(1, 1, 0), new h3d.col.IPoint(-1, 1, 0),
			new h3d.col.IPoint(1, -1, 0), new h3d.col.IPoint(-1, -1, 0),
			new h3d.col.IPoint(),

			new h3d.col.IPoint(-1, 0, 1), new h3d.col.IPoint(1, 0, 1),
			new h3d.col.IPoint(0, 1, 1), new h3d.col.IPoint(0, -1, 1),
			new h3d.col.IPoint(1, 1, 1), new h3d.col.IPoint(-1, 1, 1),
			new h3d.col.IPoint(1, -1, 1), new h3d.col.IPoint(-1, -1, 1),
			new h3d.col.IPoint(0, 0, 1),

			new h3d.col.IPoint(-1, 0, -1), new h3d.col.IPoint(1, 0, -1),
			new h3d.col.IPoint(0, 1, -1), new h3d.col.IPoint(0, -1, -1),
			new h3d.col.IPoint(1, 1, -1), new h3d.col.IPoint(-1, 1, -1),
			new h3d.col.IPoint(1, -1, -1), new h3d.col.IPoint(-1, -1, -1),
			new h3d.col.IPoint(0, 0, -1),
		];

		var tex = new h3d.mat.Texture3D(texRes, texRes, texRes, null, R8);

		var cellSize = 1.0 / gridSize;
		var maxDist = 0.0;
		var pixels = hxd.Pixels.alloc(texRes, texRes, tex.format);
		for ( k in 0...texRes ) {
			for ( j in 0...texRes ) {
				for ( i in 0...texRes ) {
					var position = new h3d.col.Point(i / texRes, j / texRes, k / texRes);
					var closestDistanceSq = hxd.Math.POSITIVE_INFINITY;
					var idx = new h3d.col.IPoint(Math.floor(i * ratio), Math.floor(j * ratio), Math.floor(k * ratio));
					for ( offset in offsets ) {
						var p = getPointTiling(idx.add(offset));
						var distance = position.distanceSq(p);
						closestDistanceSq = hxd.Math.min(distance, closestDistanceSq);
					}
					var closestDistance = Math.sqrt(closestDistanceSq);
					var normDistance = 1.0 - closestDistance / cellSize;
					pixels.setPixel(i, j, hxd.Math.iclamp(Std.int(normDistance * 255), 0, 255));
				}
			}
			tex.uploadPixels(pixels, 0, k);
		}
		return tex;
	}

	public static function generateOctave(engine : h3d.Engine, size : Int, gridSize : Int, octaves : Int, seed : Int = 0) {
		var tmp = generate(size, gridSize, seed);
		tmp.wrap = Repeat;

		var shader = new OctaveShader();
		shader.texture = tmp;
		shader.octaves = octaves;
		var pass = new h3d.pass.ScreenFx(new h3d.shader.ScreenShader());
		pass.pass.addShader(shader);

		var tex = new h3d.mat.Texture3D(size, size, size, [Target], tmp.format);
		for ( i in 0...size ) {
			engine.pushTarget(tex,i);
			shader.layer = i;
			pass.render();
			engine.popTarget();
		}

		tmp.dispose();
		return tex;
	}
}

class OctaveShader extends hxsl.Shader {

	static var SRC = {

		@global var time : Float;

		@const var octaves : Int;

		@param var layer : Float;
		@param var texture : Sampler3D;

		var pixelColor : Vec4;
		var calculatedUV : Vec2;

		function fragment() {
			pixelColor = vec4(0.0, 0.0, 0.0, 1.0);

			var w = layer / texture.size().x;
			var uvw = vec3(calculatedUV, w);

			var tot = 0.0;
			var k = 1.0;
			@unroll for (i in 0...octaves) {
				var value = texture.get(uvw).r;

				pixelColor.r += value * k;
				tot += k;
				k *= 0.5;
				uvw *= 2.0;
			}

			pixelColor.r /= tot;
		}
	}
}