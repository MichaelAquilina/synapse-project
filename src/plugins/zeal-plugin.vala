/*
 * Copyright (C) 2015 Jérémy Munsch <jeremy.munsch@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Jérémy Munsch <jeremy.munsch@gmail.com>
 *
 */

namespace Synapse
{
  /**
   * This plugin looks for zeal installed documentations
   * then it allows you to make a query on a specified doc
   * It supports queries like :
   * zeal php:php
   * or
   * zeal php constant
   * zeal php:constant
   * php constant
   * php magic constant
   * php magic constant zeal
   * php :  magic constant zeal
   *
   * and so it searches "php:magic constants" in zeal by opening it.
   * It handles complicated doc names like Apache_HTTP_Server "apache license"
   * "server license" "http license" these 3 result in "apache http server:license"
   *
   * An update would consist to aggregate the sqlite databases
   * and show results directly or develop a CLI update to zeal
   * directly.
   */
  public class ZealPlugin : Object, Activatable, ItemProvider
  {
    public bool enabled { get; set; default = true; }

    Gee.List<ZealDoc> doclist;

    public void activate ()
    {
      string docsets_path = "%s/Zeal/Zeal/docsets/".printf (Environment.get_user_data_dir ());
      doclist = new Gee.ArrayList<ZealDoc>();

      try
      {
        Dir dir = Dir.open (docsets_path, 0);
        string? name = null;

        while ((name = dir.read_name ()) != null)
        {
          string path = Path.build_filename (docsets_path, name);
          string type = "";

          if (FileUtils.test (path, FileTest.IS_REGULAR))
            type += "| REGULAR ";
          if (FileUtils.test (path, FileTest.IS_SYMLINK))
            type += "| SYMLINK ";
          if (FileUtils.test (path, FileTest.IS_DIR))
            type += "| DIR ";
          if (FileUtils.test (path, FileTest.IS_EXECUTABLE))
            type += "| EXECUTABLE ";

          if (path == "")
            continue;

          var zdoc = new ZealDoc (path);
          doclist.add (zdoc);
        }
      }
      catch (FileError e)
      {
        warning ("%s", e.message);
      }
    }

    public void deactivate ()
    {
      doclist = null;
    }

    static construct
    {
      register_plugin ();
    }

    static void register_plugin ()
    {
      PluginRegistry.get_default ().register_plugin (
        typeof (ZealPlugin),
        _("Zeal"),
        _("Zeal offline documentation (zealdocs.org)"),
        "zeal",
        register_plugin,
        Environment.find_program_in_path ("zeal") != null,
        _("zeal is not installed, please see zealdocs.org")
      );
    }

    public bool handles_query (Query query)
    {
      return (QueryFlags.ACTIONS in query.query_type && doclist.size > 0);
    }

    public async ResultSet? search (Query q) throws SearchError
    {
      Idle.add (search.callback);
      yield;
      q.check_cancellable ();

      q.query_string = q.query_string.down ().replace ("zeal", "").strip ();
      var results = new ResultSet ();
      var matchers = Query.get_matchers_for_query (q.query_string, 0, RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);

      foreach (var doc in this.doclist)
      {
        foreach (var matcher in matchers)
        {
          if (matcher.key.match (doc.scf_bundle_name))
          {
            doc.update_title (q.query_string);
            results.add (doc, matcher.value);
          }
        }

        if (doc.regex.match (q.query_string))
        {
          foreach (var part in doc.scf_bundle_name.split_set ("_ "))
            q.query_string = ZealDoc.replace_first_occurence (q.query_string, part, "");
          doc.update_title (q.query_string.replace (":", "").strip ());
          results.add (doc, MatchScore.AVERAGE);
          break;
        }
      }

      q.check_cancellable ();
      return results;
    }
  }

  public class ZealDoc : ActionMatch
  {
    public string doc_path { get; construct; }

    string query = "";
    string doc_name = "";
    public string scf_bundle_identifier = "";
    public string scf_bundle_name = "";
    public Regex regex;
    string version;

    public ZealDoc (string doc_path)
    {
      Object (
        title: "Zeal Doc",
        description: _("Zeal documentation research"),
        icon_name: "zeal",
        has_thumbnail: false,
        doc_path: doc_path
      );
    }

    construct
    {
      parse_doc_name ();
      parse_doc_bundle ();

      try
      {
        regex = new Regex ("^(%s)[ :]+([a-z0-9 -_.:;,]*)".printf (string.joinv ("|", scf_bundle_name.split_set ("_ "))), RegexCompileFlags.OPTIMIZE);
      }
      catch (GLib.RegexError e)
      {
        regex = null;
        warning ("regex error %s", e.message);
      }
    }

    public override void do_action ()
    {
      try
      {
        AppInfo ai = AppInfo.create_from_commandline ("zeal \"%s:%s\"".printf (scf_bundle_name, query), "zeal", 0);
        ai.launch (null, null);
      }
      catch (Error err)
      {
        warning ("Could not launch zeal %s", err.message);
      }
    }

    public void update_title (string query)
    {
      this.query = query;
      string version = this.version != null ? " (v%s)".printf (this.version) : "";
      title = "Search for %s in %s%s".printf (query, doc_name, version);
    }

    public static string replace_first_occurence (string str, string search, string replace)
    {
      int pos = str.index_of (search);
      if (pos < 0)
        return str;
      return str.substring (0, pos) + replace + str.substring (pos + search.length);
    }

    private void parse_doc_name ()
    {
      string data;

      try
      {
        FileUtils.get_contents (doc_path + "/meta.json", out data);
        Json.Parser parser = new Json.Parser ();

        if (parser.load_from_data (data, -1))
        {
          Json.Node node = parser.get_root ();

          if (node.get_node_type () != Json.NodeType.OBJECT)
            throw new Json.ParserError.PARSE ("Unexpected element type %s", node.type_name ());

          unowned Json.Object obj = node.get_object ();
          foreach (unowned string name in obj.get_members ())
          {
            switch (name)
            {
              case "version":
                unowned Json.Node item = obj.get_member (name);
                if (item.get_node_type () != Json.NodeType.VALUE)
                  throw new Json.ParserError.PARSE ("Unexpected element type %s", item.type_name ());
                version = obj.get_string_member ("version");
                break;

              case "name":
                unowned Json.Node item = obj.get_member (name);
                if (item.get_node_type () != Json.NodeType.VALUE)
                  throw new Json.ParserError.PARSE ("Unexpected element type %s", item.type_name ());
                doc_name = obj.get_string_member ("name");
                break;
            }
          }
        }
        else
        {
          throw new Json.ParserError.PARSE ("Unable to parse data form %s", doc_path + "/meta.json");
        }
      }
      catch (Error e)
      {
        warning ("%s", e.message);
      }
    }

    private void parse_doc_bundle ()
    {
      string contents;
      Regex exp = /\<key\>([a-zA-Z0-9 _-]+)\<\/key\>[\n\t ]*\<string\>([a-zA-Z0-9\. _-]+)\<\/string\>/;

      try
      {
        FileUtils.get_contents (doc_path + "/Contents/Info.plist", out contents, null);
      }
      catch (Error e)
      {
        warning ("Unable to read file: %s", e.message);
      }

      try
      {
        MatchInfo mi;
        for (exp.match (contents, 0, out mi) ; mi.matches () ; mi.next ())
        {
          switch (mi.fetch (1))
          {
            case "CFBundleIdentifier":
              scf_bundle_identifier = mi.fetch (2).down ();
              break;
            case "CFBundleName":
              scf_bundle_name = mi.fetch (2).down ();
              break;
          }
        }
      }
      catch (Error e)
      {
        warning ("Regex failed: %s", e.message);
      }
    }
  }
}
