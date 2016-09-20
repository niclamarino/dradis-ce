class RevisionsController < ProjectScopedController
  before_filter :load_node, except: [ :trash, :recover ]
  before_filter :load_record, except: [ :trash, :recover ]

  def index
    redirect_to action: :show, id: @record.versions.last.try(:id) || 0
  end

  def show
    # Use `reorder`, not `order`, to override Paper Trail's default scope
    @revisions = @record.versions.includes(:item).reorder("created_at DESC")
    @revision  = @revisions.find(params[:id])

    # If this is the 1st revision, there's nothing to compare. There shouldn't
    # be any links to this page, so if you get here it's a programmer error.
    raise "can't show diff first revision" unless @revision.previous.present?

    if @revision.event == "update"
      @diffed_revision = DiffedRevision.new(@revision, @record)
    end
  end

  def trash
    # Get all versions whose event is destroy.
    @revisions = RecoverableVersion.all
  end

  def recover
    version = RecoverableVersion.find(params[:id])
    if version.recover
      track_recovered(version.object)
      flash[:info] = "#{version.type} recovered"
    else
      flash[:error] = "Can't recover #{version.type}: #{version.errors.full_messages.join(',')}"
    end
    
    redirect_to trash_path
  end

  private
  def load_node
    if params[:evidence_id] || params[:note_id]
      @node = Node.includes(
        :notes, :evidence, evidence: [:issue, { issue: :tags }]
      ).find_by_id(params[:node_id])

      # FIXME: from ProjectScopedController
      initialize_nodes_sidebar
    end
  end

  def load_record
    @record = if params[:evidence_id]
                @node.evidence.find(params[:evidence_id])
              elsif params[:note_id]
                @node.notes.find(params[:note_id])
              elsif params[:issue_id]
                Issue.find(params[:issue_id])
              else
                raise 'Unable to identify record type'
              end
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'Record not found'
    redirect_to :back
  end
end
