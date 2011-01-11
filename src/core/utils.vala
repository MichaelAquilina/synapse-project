/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  namespace Utils
  {
#if VALA_0_12
    [CCode (cname = "g_utf8_strlen")]
    public static extern long g_utf8_strlen (string s, ssize_t max);
#endif
    /* Make sure setlocale was called before calling this function
     *   (Gtk.init calls it automatically)
     */
    public static string? remove_accents (string input)
    {
      string? result;
      unowned string charset;
      GLib.get_charset (out charset);
      try
      {
        result = GLib.convert (input, input.length,
                               "US-ASCII//TRANSLIT", charset);
        // no need to waste cpu cycles if the input is the same
        if (input == result) return null;
      }
      catch (ConvertError err)
      {
        result = null;
      }

      return result;
    }
    
    public static string? remove_last_unichar (string input, long offset)
    {
#if VALA_0_12
      long string_length = g_utf8_strlen (input, -1);
      if (offset < 0) {
        offset = string_length + offset;
        GLib.return_val_if_fail (offset >= 0, null);
      } else {
        GLib.return_val_if_fail (offset <= string_length, null);
      }
      long len = string_length - offset - 1;

      GLib.return_val_if_fail (offset + len <= string_length, null);
      unowned string start = input.utf8_offset (offset);
      return start.ndup (((char*) start.utf8_offset (len)) - ((char*) start));
#else
      return input.substring (offset, input.length - 1);
#endif
    }
    
    public static async bool query_exists_async (GLib.File f)
    {
      bool exists;
      try
      {
        var fi = yield f.query_info_async (FILE_ATTRIBUTE_STANDARD_TYPE,
                                           0, 0, null);
        exists = true;
      }
      catch (Error err)
      {
        exists = false;
      }

      return exists;
    }

    public class FileInfo
    {
      private static string interesting_attributes;
      static construct
      {
        interesting_attributes =
          string.join (",", FILE_ATTRIBUTE_STANDARD_TYPE,
                            FILE_ATTRIBUTE_STANDARD_IS_HIDDEN,
                            FILE_ATTRIBUTE_STANDARD_IS_BACKUP,
                            FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME,
                            FILE_ATTRIBUTE_STANDARD_ICON,
                            FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE,
                            FILE_ATTRIBUTE_THUMBNAIL_PATH,
                            null);
      }

      public string uri;
      public string parse_name;
      public QueryFlags file_type;
      public UriMatch? match_obj;
      private bool initialized;
      private Type match_obj_type;

      public FileInfo (string uri, Type obj_type)
      {
        assert (obj_type.is_a (typeof (UriMatch)));
        this.uri = uri;
        this.match_obj = null;
        this.match_obj_type = obj_type;
        this.initialized = false;
        this.file_type = QueryFlags.UNCATEGORIZED;

        var f = File.new_for_uri (uri);
        this.parse_name = f.get_parse_name ();
      }
      
      public bool is_initialized ()
      {
        return this.initialized;
      }
      
      public async void initialize ()
      {
        initialized = true;
        var f = File.new_for_uri (uri);
        try
        {
          var fi = yield f.query_info_async (interesting_attributes,
                                             0, 0, null);
          if (fi.get_file_type () == FileType.REGULAR &&
              !fi.get_is_hidden () &&
              !fi.get_is_backup ())
          {
            match_obj = (UriMatch) Object.new (match_obj_type,
              "thumbnail-path", fi.get_attribute_byte_string (FILE_ATTRIBUTE_THUMBNAIL_PATH),
              "icon-name", fi.get_icon ().to_string (),
              "uri", uri,
              "title", fi.get_display_name (),
              "description", f.get_parse_name (),
              "match-type", MatchType.GENERIC_URI,
              null
            );
            
            // let's determine the file type
            unowned string mime_type = 
              fi.get_attribute_string (FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);
            if (g_content_type_is_unknown (mime_type))
            {
              file_type = QueryFlags.UNCATEGORIZED;
            }
            else if (g_content_type_is_a (mime_type, "audio/*"))
            {
              file_type = QueryFlags.AUDIO;
            }
            else if (g_content_type_is_a (mime_type, "video/*"))
            {
              file_type = QueryFlags.VIDEO;
            }
            else if (g_content_type_is_a (mime_type, "image/*"))
            {
              file_type = QueryFlags.IMAGES;
            }
            else if (g_content_type_is_a (mime_type, "text/*"))
            {
              file_type = QueryFlags.DOCUMENTS;
            }
            // FIXME: this isn't right
            else if (g_content_type_is_a (mime_type, "application/*"))
            {
              file_type = QueryFlags.DOCUMENTS;
            }

            match_obj.file_type = file_type;
            match_obj.mime_type = mime_type;
          }
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }
      
      public async bool exists ()
      {
        var f = File.new_for_uri (uri);
        bool result = yield query_exists_async (f);
        
        return result;
      }
    }
  }
}

