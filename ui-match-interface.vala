/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
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
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;
using Cairo;
using Gee;

namespace Sezen
{
  public class SezenMatchInterface
  {
    public enum ResultType
    {
      MATCH,
      ACTION
    }
    private Match focus[2];
    private int focus_index[2];
    private Gee.List<Match> results[2];
    private string _search[2];
    private QueryFlags flag;
    private DataSink data_sink;
    
    public SezenMatchInterface ()
    {
      data_sink = new DataSink();
      flag = QueryFlags.ALL;
      focus = {null, null};
      results = {null, null};
      focus_index = {0, 0};
      _search = {"", ""};
      search_type = ResultType.MATCH;
      //result_ready.connect (debug_ready);
    }
    public QueryFlags search_flag {
      get { return flag; }
      set {
        if (value == flag)
          return;
        flag = value;
        start_search (ResultType.MATCH);
      }
    }
    public ResultType search_type {get; set; default = ResultType.MATCH;} 

    public string search {
      get { return _search[search_type]; }
      set {
        if (value == _search[search_type])
          return;
        if (value != null)
          _search[search_type] = value;
        else
          _search[search_type] = "";
        if (search_type == ResultType.MATCH)
        {
          focus[ResultType.MATCH] = null;
          focus_index[ResultType.MATCH] = 0;
          results[ResultType.MATCH] = null;
          
          _search[ResultType.ACTION] = "";
        }
        results[ResultType.ACTION] = null;
        focus[ResultType.ACTION] = null;
        focus_index[ResultType.ACTION] = 0;
        
        start_search (search_type);
      }
    }
    public Match? focus_match_at (int index)
    {
      if (index < 0 || results[search_type]==null || index >= results[search_type].size)
      {
        focus[search_type] = null;
        focus_index[search_type] = 0;
        return null;
      }
      focus[search_type] = results[search_type].get (index);
      focus_index[search_type] = index;
      if (search_type == ResultType.MATCH)
      {
        //send new actions!
        start_search (ResultType.ACTION, false);
      }
      return focus[search_type];
    }
    public void resend_results (bool match = true, bool action = true)
    {
      if (match)
        result_ready (ResultType.MATCH, results[ResultType.MATCH], focus[ResultType.MATCH], focus_index[ResultType.MATCH]);
      if (action)
        result_ready (ResultType.ACTION, results[ResultType.ACTION], focus[ResultType.ACTION], focus_index[ResultType.ACTION]);
    }
    private void start_search (ResultType t, bool update_type = true)
    {
      if (update_type)
        search_type = t;
      data_sink.cancel_search ();
      if (_search[t] == "" || t == ResultType.ACTION)
      {
        if (t == ResultType.ACTION)
        {
          if (focus[ResultType.MATCH] != null)
          {
            results[ResultType.ACTION] = data_sink.find_action_for_match (focus[ResultType.MATCH], _search[ResultType.ACTION]);
            if (results[ResultType.ACTION].size > 0)
            {
              focus[ResultType.ACTION] = results[ResultType.ACTION].first();
            }
            else
            {
              focus[ResultType.ACTION] = null;
            }
          }
          else
          {
            results[ResultType.ACTION] = null;
            focus[ResultType.ACTION] = null;
          }
          focus_index[ResultType.ACTION] = 0;
          /* If we are here, we are searching for Actions */
          result_ready (ResultType.ACTION, results[ResultType.ACTION], focus[ResultType.ACTION], focus_index[ResultType.ACTION]);
          return;
        }
        /* string is empty -> send both null results */
        result_ready (ResultType.MATCH, results[ResultType.MATCH], focus[ResultType.MATCH], focus_index[ResultType.MATCH]);
        result_ready (ResultType.ACTION, results[ResultType.ACTION], focus[ResultType.ACTION], focus_index[ResultType.ACTION]);
        return;
      }
      data_sink.search (_search[t], flag, _search_ready);
    }
    public signal void result_ready (ResultType t, Gee.List<Match>? results, Match? focus, int focus_index);
    
    /*private void debug_ready (ResultType t, Gee.List<Match>? results, Match? focus)
    {
      debug ("Sending results for %s", t == ResultType.ACTION ? "ACTION":"MATCH");
    }*/
    
    private void _search_ready (GLib.Object? obj, AsyncResult res)
    {
      try
      {
        Gee.List<Match> list = data_sink.search.end (res);
        results[ResultType.MATCH] = list;
        if (list.size > 0)
        {
          focus[ResultType.MATCH] = results[ResultType.MATCH].first();
        }
        else
        {
          focus[ResultType.MATCH] = null;
        }
        /* If we are here, we are searching for Matches */
        focus_index[ResultType.MATCH] = 0;
        result_ready (ResultType.MATCH, results[ResultType.MATCH], focus[ResultType.MATCH], focus_index[ResultType.MATCH]);
        /* Send also actions */
        start_search (ResultType.ACTION, false);
      }
      catch (SearchError err)
      {
        // most likely cancelled
      }
    }
    public Match? get_focused_match (ResultType t = ResultType.MATCH)
    {
      return focus[t];
    }
    public bool execute ()
    {
      if (focus[ResultType.MATCH] == null || focus[ResultType.ACTION] == null)
        return false;
      focus[ResultType.ACTION].execute (focus[ResultType.MATCH]);
      return true;
    }   
  }
}
