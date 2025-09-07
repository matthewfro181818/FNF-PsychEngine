package util;

import sys.FileSystem;
import sys.io.File;
import haxe.crypto.Md5;
import haxe.io.Bytes;
import haxe.zip.Reader;
import haxe.zip.Entry;

class ZipCache {
	public static function extractToCache(zipPath:String, cacheRoot:String = null):String {
		if (cacheRoot == null) cacheRoot = "./mods/.swf_cache";
		if (!FileSystem.exists(zipPath)) throw 'Zip not found: $zipPath';

		var absZip = FileSystem.fullPath(zipPath);
		var stamp  = FileSystem.stat(absZip).mtime.getTime();
		var key    = Md5.encode(absZip + "|" + stamp);
		var outDir = haxe.io.Path.join([cacheRoot, key]);

		if (FileSystem.exists(outDir) && FileSystem.isDirectory(outDir)) return outDir;

		if (!FileSystem.exists(cacheRoot)) FileSystem.createDirectory(cacheRoot);
		if (!FileSystem.exists(outDir))    FileSystem.createDirectory(outDir);

		var fin = File.read(absZip, true);
		var rdr = new Reader(fin);
		var entries = rdr.read();
		for (e in entries) writeEntry(outDir, e);
		fin.close();
		return outDir;
	}

	static function writeEntry(root:String, e:Entry) {
		var target = haxe.io.Path.join([root, e.fileName]);
		if (e.fileName.endsWith("/")) {
			if (!FileSystem.exists(target)) FileSystem.createDirectory(target);
			return;
		}
		var parent = new haxe.io.Path(target).dir;
		if (parent != null && !FileSystem.exists(parent)) FileSystem.createDirectory(parent);

		var bytes:Bytes = e.compressed ? Reader.unzip(e) : e.data;
		File.saveBytes(target, bytes);
	}
}
