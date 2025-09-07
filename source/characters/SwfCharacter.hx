package characters;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

#if FLX_ANIMATE
import flxanimate.FlxAnimate;
#end

typedef SwfCfg = {
	var ?zip:String;       // e.g. "images/characters/bf-crud.zip"
	var ?library:String;   // inside-zip or on-disk path: "library.json"
	var ?animation:String; // inside-zip or on-disk path: "data.json" (optional)
}

class SwfCharacter {
	public var curCharacter(default, null):String;
	public var flipX:Bool = false;
	public var antialiasing:Bool = true;

	final root:FlxGroup = new FlxGroup();

	#if FLX_ANIMATE
	var anim:FlxAnimate;
	#end
	var spr:FlxSprite; // Sparrow fallback

	var offsets:Map<String, FlxPoint> = [];
	var swfRenderScale:Float = 1.0;

	public function new(charName:String, x:Float, y:Float) {
		curCharacter = charName;
		var cfgPath = resolveCharacterJson(charName);
		var cfg:Dynamic = Json.parse(File.getContent(cfgPath));

		flipX = cfg.flip_x == true;
		antialiasing = !(cfg.no_antialiasing == true);
		var baseScale:Float = (cfg.scale != null ? cfg.scale : 1.0);
		swfRenderScale = (cfg.swfRenderScale != null ? cfg.swfRenderScale : 1.0);

		switch (Std.string(cfg.renderType)) {
			case "swf":
				#if FLX_ANIMATE
				loadFlxAnimate(cfg, x, y, baseScale * swfRenderScale);
				#else
				loadFallbackAtlas(cfg, x, y, baseScale);
				#end
			default:
				loadFallbackAtlas(cfg, x, y, baseScale);
		}

		fillOffsets(cfg);
		playAnim("idle");
	}

	// ----------------- Psych helpers -----------------
	static function resolveCharacterJson(name:String):String {
		// Psych Engine mods search path
		var tries = [
			Paths.modFolders('data/characters/$name.json'),
			Paths.getPath('data/characters/$name.json', TEXT)
		];
		for (p in tries) if (p != null && FileSystem.exists(p)) return p;
		throw 'Character JSON not found: $name';
	}

	static function resolvePath(p:String):String {
		// tries mods first, then assets
		var m = Paths.modFolders(p);
		if (m != null && FileSystem.exists(m)) return m;
		var a = Paths.getPath(p, TEXT);
		if (a != null && FileSystem.exists(a)) return a;
		return p; // as-is (absolute or working dir)
	}

	inline function addTo(group:FlxGroup):Void group.add(root);

	// ----------------- FLX_ANIMATE path -----------------
	#if FLX_ANIMATE
	function loadFlxAnimate(cfg:Dynamic, x:Float, y:Float, scale:Float) {
		anim = new FlxAnimate(x, y);
		anim.antialiasing = antialiasing;
		anim.flipX = flipX;

		var libPath:String;
		var timelinePath:String = null;

		var swf:SwfCfg = cfg.swf;
		if (swf != null && swf.zip != null) {
			var zipDisk = resolvePath(swf.zip);
			var extracted = util.ZipCache.extractToCache(zipDisk);
			var innerLib = (swf.library != null ? swf.library : "library.json");
			libPath = haxe.io.Path.join([extracted, innerLib]);
			if (swf.animation != null) timelinePath = haxe.io.Path.join([extracted, swf.animation]);
		} else {
			libPath = resolvePath(swf.library);
			if (swf.animation != null) timelinePath = resolvePath(swf.animation);
		}

		anim.loadLibrary(libPath);
		if (timelinePath != null) anim.loadAtlas(timelinePath);

		// Register animations by symbol names (Psych-style fields)
		for (a in (cfg.animations:Array<Dynamic>)) {
			var logicalName:String = a.name;       // e.g. "singLEFT"
			var symbol:String = a.anim;            // e.g. "singLEFT" (timeline/class name)
			var fps:Int = a.fps != null ? a.fps : 24;
			var loop:Bool = a.loop == true;
			anim.anim.addBySymbol(logicalName, symbol, fps, loop);
		}

		anim.scale.set(scale, scale);
		anim.updateHitbox();
		root.add(anim);
	}
	#end

	// ----------------- Sparrow fallback -----------------
	function loadFallbackAtlas(cfg:Dynamic, x:Float, y:Float, scale:Float) {
		spr = new FlxSprite(x, y);
		spr.antialiasing = antialiasing;
		spr.flipX = flipX;

		if (cfg.fallbackAtlas != null) {
			var baseNoPng = Std.string(cfg.fallbackAtlas.image);
			if (StringTools.endsWith(baseNoPng, ".png"))
				baseNoPng = baseNoPng.substr(0, baseNoPng.length - 4);
			spr.frames = Paths.getSparrowAtlas(baseNoPng);
		} else if (cfg.image != null) {
			// Psych's old "image" field (without extension)
			spr.frames = Paths.getSparrowAtlas(Std.string(cfg.image));
		} else {
			throw "No atlas/image specified for fallback";
		}

		for (a in (cfg.animations:Array<Dynamic>)) {
			var logicalName:String = a.name;
			var prefix:String = a.anim; // expect exporter to keep prefix == symbol
			var fps:Int = a.fps != null ? a.fps : 24;
			var loop:Bool = a.loop == true;
			spr.animation.addByPrefix(logicalName, prefix, fps, loop);
		}

		spr.scale.set(scale, scale);
		spr.updateHitbox();
		root.add(spr);
	}

	// ----------------- Controls -----------------
	public function playAnim(name:String, force:Bool = true):Void {
		var o = offsets.exists(name) ? offsets.get(name) : FlxPoint.get();
		#if FLX_ANIMATE
		if (anim != null) {
			if (force) anim.anim.play(name, true); else anim.anim.play(name, false);
			anim.offset.set(o.x, o.y);
			return;
		}
		#end
		if (spr != null) {
			spr.animation.play(name, force);
			spr.offset.set(o.x, o.y);
		}
	}

	public function setColor(c:FlxColor):Void {
		#if FLX_ANIMATE
		if (anim != null) anim.color = c;
		#end
		if (spr != null) spr.color = c;
	}

	public function addTo(group:FlxGroup):Void group.add(root);

	function fillOffsets(cfg:Dynamic) {
		offsets = [];
		for (a in (cfg.animations:Array<Dynamic>)) {
			var off:Array<Dynamic> = a.offsets;
			var ox = (off != null && off.length > 0) ? off[0] : 0;
			var oy = (off != null && off.length > 1) ? off[1] : 0;
			offsets.set(a.name, FlxPoint.get(ox, oy));
		}
	}
}
