defmodule SlackClone.Search do
  @moduledoc """
  The Search context for full-text search and advanced filtering.
  """

  import Ecto.Query, warn: false
  alias SlackClone.Repo
  alias SlackClone.Search.{Query, ElasticsearchClient}
  alias SlackClone.Messages.Message
  alias SlackClone.Channels.Channel
  alias SlackClone.Accounts.User
  alias SlackClone.Files.FileAttachment

  @doc """
  Performs a comprehensive search across messages, files, channels, and users.
  """
  def search(workspace_id, query_string, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    search_type = Keyword.get(opts, :type, "all")
    filters = Keyword.get(opts, :filters, %{})
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    # Log the search query for analytics
    log_search_query(user_id, workspace_id, query_string, search_type, filters)

    case search_type do
      "messages" -> search_messages(workspace_id, query_string, filters, limit, offset, user_id)
      "channels" -> search_channels(workspace_id, query_string, filters, limit, offset, user_id)
      "people" -> search_people(workspace_id, query_string, filters, limit, offset, user_id)
      "files" -> search_files(workspace_id, query_string, filters, limit, offset, user_id)
      "all" -> search_all(workspace_id, query_string, filters, limit, offset, user_id)
    end
  end

  @doc """
  Searches messages using full-text search with PostgreSQL.
  """
  def search_messages(workspace_id, query_string, filters, limit, offset, user_id) do
    base_query = 
      Message
      |> join(:inner, [m], c in Channel, on: m.channel_id == c.id)
      |> where([m, c], c.workspace_id == ^workspace_id)
      |> preload([:user, :channel, :file_attachments, :reactions])

    # Apply full-text search if query provided
    query_with_search = 
      if query_string && String.length(query_string) > 0 do
        tsquery = build_tsquery(query_string)
        
        base_query
        |> where([m], fragment("? @@ ?", m.search_vector, ^tsquery))
        |> order_by([m], desc: fragment("ts_rank(?, ?)", m.search_vector, ^tsquery))
      else
        base_query |> order_by([m], desc: m.inserted_at)
      end

    # Apply filters
    filtered_query = apply_message_filters(query_with_search, filters, user_id)

    messages = 
      filtered_query
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    total_count = 
      filtered_query
      |> exclude(:preload)
      |> exclude(:order_by)
      |> exclude(:limit)
      |> exclude(:offset)
      |> Repo.aggregate(:count)

    %{
      results: messages,
      total_count: total_count,
      type: "messages",
      has_more: length(messages) == limit
    }
  end

  @doc """
  Searches channels using full-text search.
  """
  def search_channels(workspace_id, query_string, filters, limit, offset, user_id) do
    base_query = 
      Channel
      |> where([c], c.workspace_id == ^workspace_id)
      |> preload([:workspace, :members])

    # Apply full-text search
    query_with_search = 
      if query_string && String.length(query_string) > 0 do
        tsquery = build_tsquery(query_string)
        
        base_query
        |> where([c], fragment("? @@ ?", c.search_vector, ^tsquery))
        |> order_by([c], desc: fragment("ts_rank(?, ?)", c.search_vector, ^tsquery))
      else
        base_query |> order_by([c], asc: c.name)
      end

    # Apply filters
    filtered_query = apply_channel_filters(query_with_search, filters, user_id)

    channels = 
      filtered_query
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    total_count = 
      filtered_query
      |> exclude(:preload)
      |> exclude(:order_by)
      |> exclude(:limit)
      |> exclude(:offset)
      |> Repo.aggregate(:count)

    %{
      results: channels,
      total_count: total_count,
      type: "channels",
      has_more: length(channels) == limit
    }
  end

  @doc """
  Searches people/users in the workspace.
  """
  def search_people(workspace_id, query_string, _filters, limit, offset, _user_id) do
    base_query = 
      User
      |> join(:inner, [u], wm in "workspace_memberships", on: wm.user_id == u.id)
      |> where([u, wm], wm.workspace_id == ^workspace_id)
      |> where([u], u.is_active == true)

    # Apply search filter
    query_with_search = 
      if query_string && String.length(query_string) > 0 do
        search_pattern = "%#{query_string}%"
        
        base_query
        |> where([u], 
          ilike(u.display_name, ^search_pattern) or
          ilike(u.email, ^search_pattern) or
          ilike(u.username, ^search_pattern)
        )
        |> order_by([u], 
          [asc: fragment("CASE WHEN ? ILIKE ? THEN 1 ELSE 2 END", u.display_name, ^search_pattern),
           asc: u.display_name])
      else
        base_query |> order_by([u], asc: u.display_name)
      end

    users = 
      query_with_search
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    total_count = 
      query_with_search
      |> exclude(:order_by)
      |> exclude(:limit)
      |> exclude(:offset)
      |> Repo.aggregate(:count)

    %{
      results: users,
      total_count: total_count,
      type: "people",
      has_more: length(users) == limit
    }
  end

  @doc """
  Searches files using metadata and content.
  """
  def search_files(workspace_id, query_string, filters, limit, offset, user_id) do
    base_query = 
      FileAttachment
      |> join(:inner, [f], m in Message, on: f.message_id == m.id)
      |> join(:inner, [f, m], c in Channel, on: m.channel_id == c.id)
      |> where([f, m, c], c.workspace_id == ^workspace_id)
      |> preload([:user, message: [:channel]])

    # Apply search filter
    query_with_search = 
      if query_string && String.length(query_string) > 0 do
        search_pattern = "%#{query_string}%"
        
        base_query
        |> where([f], 
          ilike(f.filename, ^search_pattern) or
          ilike(f.content_type, ^search_pattern)
        )
      else
        base_query
      end

    # Apply file-specific filters
    filtered_query = apply_file_filters(query_with_search, filters, user_id)

    files = 
      filtered_query
      |> order_by([f], desc: f.inserted_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    total_count = 
      filtered_query
      |> exclude(:preload)
      |> exclude(:order_by)
      |> exclude(:limit)
      |> exclude(:offset)
      |> Repo.aggregate(:count)

    %{
      results: files,
      total_count: total_count,
      type: "files",
      has_more: length(files) == limit
    }
  end

  @doc """
  Performs search across all content types.
  """
  def search_all(workspace_id, query_string, filters, limit, offset, user_id) do
    per_type_limit = div(limit, 4)
    
    # Search each type in parallel
    tasks = [
      Task.async(fn -> search_messages(workspace_id, query_string, filters, per_type_limit, 0, user_id) end),
      Task.async(fn -> search_channels(workspace_id, query_string, filters, per_type_limit, 0, user_id) end),
      Task.async(fn -> search_people(workspace_id, query_string, filters, per_type_limit, 0, user_id) end),
      Task.async(fn -> search_files(workspace_id, query_string, filters, per_type_limit, 0, user_id) end)
    ]

    results = Task.await_many(tasks, 10_000)
    
    %{
      results: %{
        messages: Enum.at(results, 0),
        channels: Enum.at(results, 1),
        people: Enum.at(results, 2),
        files: Enum.at(results, 3)
      },
      type: "all"
    }
  end

  @doc """
  Gets search suggestions based on user's search history and popular queries.
  """
  def get_search_suggestions(workspace_id, user_id, query_prefix, limit \\ 10) do
    # Get recent queries from this user
    user_queries = 
      Query
      |> where([q], q.user_id == ^user_id and q.workspace_id == ^workspace_id)
      |> where([q], ilike(q.query, ^"#{query_prefix}%"))
      |> order_by([q], desc: q.executed_at)
      |> limit(^div(limit, 2))
      |> Repo.all()
      |> Enum.map(& &1.query)

    # Get popular queries from all users
    popular_queries = 
      Query
      |> where([q], q.workspace_id == ^workspace_id)
      |> where([q], ilike(q.query, ^"#{query_prefix}%"))
      |> group_by([q], q.query)
      |> order_by([q], desc: count(q.id))
      |> limit(^div(limit, 2))
      |> select([q], q.query)
      |> Repo.all()

    (user_queries ++ popular_queries)
    |> Enum.uniq()
    |> Enum.take(limit)
  end

  @doc """
  Gets search analytics for the workspace.
  """
  def get_search_analytics(workspace_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    start_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    # Top search queries
    top_queries = 
      Query
      |> where([q], q.workspace_id == ^workspace_id)
      |> where([q], q.executed_at > ^start_date)
      |> group_by([q], q.query)
      |> order_by([q], desc: count(q.id))
      |> limit(10)
      |> select([q], %{query: q.query, count: count(q.id)})
      |> Repo.all()

    # Search volume by day
    daily_volume = 
      Query
      |> where([q], q.workspace_id == ^workspace_id)
      |> where([q], q.executed_at > ^start_date)
      |> group_by([q], fragment("DATE(?)", q.executed_at))
      |> order_by([q], asc: fragment("DATE(?)", q.executed_at))
      |> select([q], %{date: fragment("DATE(?)", q.executed_at), count: count(q.id)})
      |> Repo.all()

    # Zero-result queries
    zero_result_queries = 
      Query
      |> where([q], q.workspace_id == ^workspace_id)
      |> where([q], q.executed_at > ^start_date)
      |> where([q], q.results_count == 0)
      |> group_by([q], q.query)
      |> order_by([q], desc: count(q.id))
      |> limit(10)
      |> select([q], %{query: q.query, count: count(q.id)})
      |> Repo.all()

    %{
      top_queries: top_queries,
      daily_volume: daily_volume,
      zero_result_queries: zero_result_queries
    }
  end

  ## Private Functions

  defp log_search_query(user_id, workspace_id, query_string, search_type, filters) when not is_nil(user_id) do
    %Query{
      user_id: user_id,
      workspace_id: workspace_id,
      query: query_string,
      search_type: search_type,
      filters: filters
    }
    |> Query.changeset(%{})
    |> Repo.insert()
  end
  defp log_search_query(_, _, _, _, _), do: :ok

  defp build_tsquery(query_string) do
    query_string
    |> String.replace(~r/[^\w\s]/, "")
    |> String.split()
    |> Enum.map(&"#{&1}:*")
    |> Enum.join(" & ")
  end

  defp apply_message_filters(query, filters, user_id) do
    query
    |> filter_by_channel(filters["channel_ids"])
    |> filter_by_user(filters["user_ids"])
    |> filter_by_date_range(filters["from_date"], filters["to_date"])
    |> filter_by_has_attachments(filters["has_attachments"])
    |> filter_by_thread_replies(filters["in_threads"])
    |> maybe_filter_by_member_access(user_id)
  end

  defp apply_channel_filters(query, filters, user_id) do
    query
    |> filter_channels_by_type(filters["channel_type"])
    |> filter_channels_by_privacy(filters["is_private"])
    |> maybe_filter_channels_by_membership(user_id, filters["member_only"])
  end

  defp apply_file_filters(query, filters, _user_id) do
    query
    |> filter_files_by_type(filters["file_type"])
    |> filter_files_by_size(filters["min_size"], filters["max_size"])
    |> filter_by_date_range(filters["from_date"], filters["to_date"])
  end

  # Message filter implementations
  defp filter_by_channel(query, nil), do: query
  defp filter_by_channel(query, channel_ids) when is_list(channel_ids) do
    where(query, [m, c], m.channel_id in ^channel_ids)
  end
  defp filter_by_channel(query, channel_id) do
    where(query, [m, c], m.channel_id == ^channel_id)
  end

  defp filter_by_user(query, nil), do: query
  defp filter_by_user(query, user_ids) when is_list(user_ids) do
    where(query, [m, c], m.user_id in ^user_ids)
  end
  defp filter_by_user(query, user_id) do
    where(query, [m, c], m.user_id == ^user_id)
  end

  defp filter_by_date_range(query, nil, nil), do: query
  defp filter_by_date_range(query, from_date, nil) when not is_nil(from_date) do
    where(query, [m, c], m.inserted_at >= ^from_date)
  end
  defp filter_by_date_range(query, nil, to_date) when not is_nil(to_date) do
    where(query, [m, c], m.inserted_at <= ^to_date)
  end
  defp filter_by_date_range(query, from_date, to_date) do
    where(query, [m, c], m.inserted_at >= ^from_date and m.inserted_at <= ^to_date)
  end

  defp filter_by_has_attachments(query, nil), do: query
  defp filter_by_has_attachments(query, true) do
    where(query, [m, c], 
      fragment("EXISTS (SELECT 1 FROM file_attachments fa WHERE fa.message_id = ?)", m.id)
    )
  end
  defp filter_by_has_attachments(query, false) do
    where(query, [m, c], 
      fragment("NOT EXISTS (SELECT 1 FROM file_attachments fa WHERE fa.message_id = ?)", m.id)
    )
  end

  defp filter_by_thread_replies(query, nil), do: query
  defp filter_by_thread_replies(query, true) do
    where(query, [m, c], not is_nil(m.thread_id))
  end
  defp filter_by_thread_replies(query, false) do
    where(query, [m, c], is_nil(m.thread_id))
  end

  defp maybe_filter_by_member_access(query, nil), do: query
  defp maybe_filter_by_member_access(query, user_id) do
    # Only show messages from channels the user has access to
    query
    |> join(:inner, [m, c], cm in "channel_memberships", on: cm.channel_id == c.id)
    |> where([m, c, cm], cm.user_id == ^user_id)
  end

  # Channel filter implementations
  defp filter_channels_by_type(query, nil), do: query
  defp filter_channels_by_type(query, channel_type) do
    where(query, [c], c.type == ^channel_type)
  end

  defp filter_channels_by_privacy(query, nil), do: query
  defp filter_channels_by_privacy(query, is_private) do
    where(query, [c], c.is_private == ^is_private)
  end

  defp maybe_filter_channels_by_membership(query, nil, _), do: query
  defp maybe_filter_channels_by_membership(query, _user_id, false), do: query
  defp maybe_filter_channels_by_membership(query, user_id, true) do
    join(query, :inner, [c], cm in "channel_memberships", on: cm.channel_id == c.id)
    |> where([c, cm], cm.user_id == ^user_id)
  end

  # File filter implementations
  defp filter_files_by_type(query, nil), do: query
  defp filter_files_by_type(query, file_type) do
    where(query, [f], ilike(f.content_type, ^"#{file_type}%"))
  end

  defp filter_files_by_size(query, nil, nil), do: query
  defp filter_files_by_size(query, min_size, nil) when not is_nil(min_size) do
    where(query, [f], f.file_size >= ^min_size)
  end
  defp filter_files_by_size(query, nil, max_size) when not is_nil(max_size) do
    where(query, [f], f.file_size <= ^max_size)
  end
  defp filter_files_by_size(query, min_size, max_size) do
    where(query, [f], f.file_size >= ^min_size and f.file_size <= ^max_size)
  end
end