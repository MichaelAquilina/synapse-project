/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 * Copyright (C) 2010 Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *
 */

using Gee;

namespace Synapse.Gui
{
  public class CategoryConfig : ConfigObject
  {
    /* Found in config:  ui->categories */
    public class Category : GLib.Object
    {
      public string name {get; set; default = _("All");}
      public QueryFlags flags {
        get; set; default = QueryFlags.ALL;
      }
      public Category (string name, QueryFlags flags = QueryFlags.ALL)
      {
        this.name = name;
        this.flags = flags;
      }
      
      public Category.from_string (string key)
      {
        string[] nameflags = key.split ("@", 2);
        if (nameflags.length == 2)
        {
          this.name = nameflags[0];
          this.flags = (QueryFlags) uint64.parse (nameflags[1]);
        }
        else if (nameflags.length == 1)
        {
          this.name = nameflags[0];
          this.flags = QueryFlags.ALL;
        }
        // else keep defaults
      }
      
      public static string name_query_to_string (string name, QueryFlags flags)
      {
        return "%s@%u".printf (name, flags);
      }
      
      public string to_string () {
        return "%s@%u".printf (this.name, this.flags);
      }
    }

    public string[] list {
      get; set; default = {
        Category.name_query_to_string ( _("Actions"), QueryFlags.ACTIONS ),
        Category.name_query_to_string ( _("Audio"), QueryFlags.AUDIO ),
        Category.name_query_to_string ( _("Applications"), QueryFlags.APPLICATIONS ),
        Category.name_query_to_string ( _("All"), QueryFlags.ALL ),
        Category.name_query_to_string ( _("Places"), QueryFlags.PLACES ),
        Category.name_query_to_string ( _("Documents"), QueryFlags.DOCUMENTS ),
        Category.name_query_to_string ( _("Images"), QueryFlags.IMAGES ),
        Category.name_query_to_string ( _("Video"), QueryFlags.VIDEO ),
        Category.name_query_to_string ( _("Internet"), QueryFlags.INTERNET | QueryFlags.INCLUDE_REMOTE )
      };
    }
    
    public int default_category_index {
      get; set; default = 3;
    }
    
    public Gee.List<Category> categories {
      get {
        return _categories;
      }
    }
    
    public Gee.Map<QueryFlags, string> labels {
      get {
        return _labels;
      }
    }
    
    public Gee.Map<QueryFlags, string> _labels;
    private Gee.List<Category> _categories;
    construct
    {
      _categories = new Gee.ArrayList<Category> ();
      _labels = new Gee.HashMap<QueryFlags, string> ();
      init_labels ();
      this.update_categories ();
    }
    
    private void init_labels ()
    {
      //_labels.set (QueryFlags.ALL, _("All")); // Do not remove!
      
      _labels.set (QueryFlags.INCLUDE_REMOTE, _("Include remote content"));
      _labels.set (QueryFlags.ACTIONS, _("Actions"));
      _labels.set (QueryFlags.PLACES, _("Places"));
      _labels.set (QueryFlags.AUDIO, _("Audio"));
      _labels.set (QueryFlags.APPLICATIONS, _("Applications"));
      _labels.set (QueryFlags.DOCUMENTS, _("Documents"));
      _labels.set (QueryFlags.IMAGES, _("Images"));
      _labels.set (QueryFlags.VIDEO, _("Video"));
      _labels.set (QueryFlags.INTERNET, _("Internet"));
      //_labels.set (QueryFlags.FILES, _("Files"));
      _labels.set (QueryFlags.UNCATEGORIZED, _("Uncategorized"));
    }
    
    public void update_categories ()
    {
      _categories.clear ();
      foreach (unowned string s in list)
      {
        _categories.add (new Category.from_string (s));
      }
      if (_categories.size < 1)
      {
        //Whooot?! This cannot be true!
        list = {
          Category.name_query_to_string ( _("All"), QueryFlags.ALL )
        };
        update_categories ();
        return;
      }
      if (default_category_index >= _categories.size)
      {
        default_category_index = _categories.size / 2;
      }
    }
  }
}
