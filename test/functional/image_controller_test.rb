# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class ImageControllerTest < FunctionalTestCase

  def test_list_images
    get_with_dump(:list_images)
    assert_response('list_images')
  end

  def test_images_by_user
    get_with_dump(:images_by_user, :id => @rolf.id)
    assert_response('list_images')
  end

  def test_images_for_project
    get_with_dump(:images_for_project, :id => projects(:bolete_project).id)
    assert_response('list_images')
  end

  def test_mushroom_app_report
    get(:images_for_mushroom_app, :names => names(:agaricus_campestris).text_name)
  end

  def test_next_image
    get_with_dump(:next_image, :id => 2)
    assert_response(:action => "show_image", :id => 1)
  end

  def test_next_image_ss
    outer = Query.lookup_and_save(:Observation, :in_set, :ids => [2,1,4,3])
    inner = Query.lookup_and_save(:Image, :inside_observation, :outer => outer,
                                  :observation => 2, :by => :id)

    # Make sure the outer query is working right first.
    outer.current_id = 2
    new_outer = outer.next
    assert_equal(outer, new_outer)
    assert_equal(1, outer.current_id)
    assert_equal(0, outer.current.images.size)
    new_outer = outer.next
    assert_equal(outer, new_outer)
    assert_equal(4, outer.current_id)
    assert_equal(1, outer.current.images.size)
    new_outer = outer.next
    assert_equal(outer, new_outer)
    assert_equal(3, outer.current_id)
    assert_equal(1, outer.current.images.size)
    new_outer = outer.next
    assert_equal(nil, new_outer)

    # No more images for obs #2, so goes to next obs (#1), but this has no
    # images, so goes to next (#4), this has one image (#6).  (Shouldn't
    # care that outer query has changed, inner query remembers where it
    # was when inner query was created.)
    inner.current_id = 2
    assert(new_inner = inner.next)
    assert_not_equal(inner, new_inner)
    assert_equal(6, new_inner.current_id)
    save_query = Query.last
    assert(new_new_inner = new_inner.next)
    assert_not_equal(new_inner, new_new_inner)
    assert_equal(5, new_new_inner.current_id)
    assert_nil(new_new_inner.next)

    params = {
      :id => 2,
      :params => @controller.query_params(inner),
    }.flatten
    get(:next_image, params)
    assert_response(:action => "show_image", :id => 6,
                    :params => @controller.query_params(save_query))
  end

  # Test next_image in the context of a search
  def test_next_image_search
    image = Image.find(5)

    # Create simple index.
    query = Query.lookup_and_save(:Image, :by_user, :user => @rolf)
    assert_equal([8, 6, 5, 4, 3], query.result_ids)

    # See what should happen if we look up an Image search and go to next.
    query.current = image
    assert(new_query = query.next)
    assert_equal(query, new_query)
    assert_equal(4, new_query.current_id)

    # Now do it for real.
    params = {
      :id => 5,
      :params => @controller.query_params(query),
    }.flatten
    get(:next_image, params)
    assert_response(:action => "show_image", :id => 4,
                    :params => @controller.query_params(query))
  end

  def test_prev_image
    get_with_dump(:prev_image, :id => 1)
    assert_response(:action => "show_image", :id => 2)
  end

  def test_prev_image_ss
    outer = Query.lookup_and_save(:Observation, :in_set, :ids => [2,1,4,3])
    inner = Query.lookup_and_save(:Image, :inside_observation, :outer => outer,
                                  :observation => 4, :by => :id)

    # Make sure the outer query is working right first.
    outer.current_id = 4
    new_outer = outer.prev
    assert_equal(outer, new_outer)
    assert_equal(1, outer.current_id)
    assert_equal(0, outer.current.images.size)
    new_outer = outer.prev
    assert_equal(outer, new_outer)
    assert_equal(2, outer.current_id)
    assert_equal(2, outer.current.images.size)
    new_outer = outer.prev
    assert_equal(nil, new_outer)

    # No more images for obs #4, so goes to next obs (#1), but this has no
    # images, so goes to next (#2), this has two images (#1 and #2).
    # (Shouldn't care that outer query has changed, inner query remembers where
    # it was when inner query was created.)
    inner.current_id = 6
    assert(new_inner = inner.prev)
    assert_not_equal(inner, new_inner)
    assert_equal(2, new_inner.current_id)
    assert(new_new_inner = new_inner.prev)
    assert_equal(new_inner, new_new_inner)
    assert_equal(1, new_inner.current_id)
    assert_nil(new_inner.prev)

    params = {
      :id => 6,
      :params => @controller.query_params(inner),
    }.flatten
    get(:prev_image, params)
    assert_response(:action => "show_image", :id => 2,
                    :params => @controller.query_params(Query.last))
  end

  def test_show_original
    get_with_dump(:show_original, :id => 1)
    assert_response(:action => "show_image", :size => 'full_size', :id => 1)
  end

  def test_show_image
    get_with_dump(:show_image, :id => 1)
    assert_response('show_image')
    for size in Image.all_sizes + [:original]
      get(:show_image, :id => 1, :size => size)
      assert_response('show_image')
    end
  end

  def test_show_image_edit_links
    img = images(:in_situ)
    proj = projects(:bolete_project)
    assert_equal(@mary.id, img.user_id)                       # owned by mary
    assert(img.projects.include?(proj))                       # owned by bolete project
    assert_equal([@dick.id], proj.user_group.users.map(&:id)) # dick is only member of project

    login('rolf')
    get(:show_image, :id => img.id)
    assert_select('a[href*=edit_image]', :count => 0)
    assert_select('a[href*=destroy_image]', :count => 0)
    get(:edit_image, :id => img.id)
    assert_response(:redirect)
    get(:destroy_image, :id => img.id)
    assert_flash_error

    login('mary')
    get(:show_image, :id => img.id)
    assert_select('a[href*=edit_image]', :minimum => 1)
    assert_select('a[href*=destroy_image]', :minimum => 1)
    get(:edit_image, :id => img.id)
    assert_response(:success)

    login('dick')
    get(:show_image, :id => img.id)
    assert_select('a[href*=edit_image]', :minimum => 1)
    assert_select('a[href*=destroy_image]', :minimum => 1)
    get(:edit_image, :id => img.id)
    assert_response(:success)
    get(:destroy_image, :id => img.id)
    assert_flash_success
  end

  def test_image_search
    get_with_dump(:image_search, :pattern => 'Notes')
    assert_response('list_images')
    assert_equal(:query_title_pattern_search.t(:types => 'Images', :pattern => 'Notes'),
                 @controller.instance_variable_get('@title'))
    get_with_dump(:image_search, :pattern => 'Notes', :page => 2)
    assert_response('list_images')
    assert_equal(:query_title_pattern_search.t(:types => 'Images', :pattern => 'Notes'),
                 @controller.instance_variable_get('@title'))
  end

  def test_image_search_next
    get_with_dump(:image_search, :pattern => 'Notes')
    assert_response('list_images')
  end

  def test_image_search_by_number
    get_with_dump(:image_search, :pattern => 3)
    assert_response(:action => "show_image", :id => 3)
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Image, :advanced_search,
      :name => "Don't know",
      :user => "myself",
      :content => "Long pink stem and small pink cap",
      :location => "Eastern Oklahoma"
    )
    get(:advanced_search, @controller.query_params(query))
    assert_response('list_images')
  end

  def test_add_image
    requires_login(:add_image, :id => observations(:coprinus_comatus_obs).id)
    assert_form_action(:action => 'add_image', :id => observations(:coprinus_comatus_obs).id)
    # Check that image cannot be added to an observation the user doesn't own.
    get_with_dump(:add_image, :id => observations(:minimal_unknown).id)
    assert_response(:controller => "observer", :action => "show_observation")
  end

  # Test reusing an image by id number.
  def test_add_image_to_obs
    obs = observations(:coprinus_comatus_obs)
    image = images(:disconnected_coprinus_comatus_image)
    assert(!obs.images.member?(image))
    requires_login(:reuse_image, :mode => 'observation', :obs_id => obs.id,
                   :img_id => image.id)
    assert_response(:controller => :observer, :action => :show_observation)
    assert(obs.reload.images.member?(image))
  end

  def test_license_updater
    requires_login(:license_updater)
    assert_form_action(:action => 'license_updater')
  end

  def test_update_licenses
    contribution = @rolf.contribution
    example_image    = images(:agaricus_campestris_image)
    user_id          = example_image.user_id
    copyright_holder = example_image.copyright_holder
    old_license      = example_image.license

    target_license = example_image.license
    new_license    = licenses(:ccwiki30)
    assert_not_equal(target_license, new_license)
    assert_equal(0, example_image.copyright_changes.length)

    target_count = Image.find_all_by_user_id_and_license_id_and_copyright_holder(user_id, target_license.id, copyright_holder).length
    new_count    = Image.find_all_by_user_id_and_license_id_and_copyright_holder(user_id, new_license.id, copyright_holder).length
    assert(target_count > 0)
    assert(new_count == 0)

    params = {
      :updates => {
        '1' => {
          'old_id' => target_license.id.to_s,
          'new_id' => new_license.id.to_s,
          'old_holder' => copyright_holder,
          'new_holder' => copyright_holder
        }
      }
    }
    post_requires_login(:license_updater, params)
    assert_response('license_updater')
    assert_equal(contribution, @rolf.reload.contribution)

    target_count_after = Image.find_all_by_user_id_and_license_id_and_copyright_holder(user_id, target_license.id, copyright_holder).length
    new_count_after    = Image.find_all_by_user_id_and_license_id_and_copyright_holder(user_id, new_license.id, copyright_holder).length
    assert(target_count_after < target_count)
    assert(new_count_after > new_count)
    assert_equal(target_count_after + new_count_after, target_count + new_count)
    example_image.reload
    assert_equal(new_license.id, example_image.license_id)
    assert_equal(copyright_holder, example_image.copyright_holder)
    assert_equal(1, example_image.copyright_changes.length)
    assert_equal(old_license.id, example_image.copyright_changes.last.license_id)

    # This empty string caused it to crash in the wild.
    example_image.reload
    example_image.copyright_holder = ''
    example_image.save
    # (note: the above creates a new entry in copyright_changes!!)
    params = {
      :updates => {
        '1' => {
          'old_id' => new_license.id.to_s,
          'new_id' => new_license.id.to_s,
          'old_holder' => '',
          'new_holder' => 'A. H. Smith'
        }
      }
    }
    post_requires_login(:license_updater, params)
    assert_response('license_updater')
    example_image.reload
    assert_equal('A. H. Smith', example_image.copyright_holder)
    assert_equal(3, example_image.copyright_changes.length)
    assert_equal(new_license.id, example_image.copyright_changes.last.license_id)
    assert_equal('', example_image.copyright_changes.last.name)
  end

  def test_delete_images
    obs = observations(:detailed_unknown)
    keep = images(:turned_over)
    remove = images(:in_situ)
    assert(obs.images.member?(keep))
    assert(obs.images.member?(remove))
    assert_equal(remove.id, obs.thumb_image_id)

    selected = {}
    selected[keep.id.to_s] = "no"
    selected[remove.id.to_s] = "yes"
    params = {
      :id => obs.id.to_s,
      :selected => selected
    }
    contribution = @mary.contribution
    post_requires_login(:remove_images, params, 'mary')
    assert_response(:controller => :observer, :action => :show_observation)
    assert_equal(contribution, @mary.reload.contribution)
    assert(obs.reload.images.member?(keep))
    assert(!obs.images.member?(remove))
    assert_equal(keep.id, obs.thumb_image_id)

    selected = {}
    selected[keep.id.to_s] = "yes"
    params = {
      :id => obs.id.to_s,
      :selected => selected
    }
    post(:remove_images, params)
    assert_response(:controller => "observer", :action => "show_observation")
    assert_equal(contribution, @mary.reload.contribution)
    assert(!obs.reload.images.member?(keep))
    assert_equal(nil, obs.thumb_image_id)
  end

  def test_destroy_image
    image = images(:turned_over)
    obs = image.observations.first
    assert(obs.images.member?(image))
    params = { :id => image.id.to_s }
    assert_equal('mary', image.user.login)
    contribution = image.user.contribution
    requires_user(:destroy_image, :show_image, params, 'mary')
    assert_response(:action => :list_images)
    assert_equal(contribution - 10, @mary.reload.contribution)
    assert(!obs.reload.images.member?(image))
  end

  def test_edit_image
    image = images(:connected_coprinus_comatus_image)
    params = { "id" => image.id.to_s }
    assert("rolf" == image.user.login)
    requires_user(:edit_image, ['image', 'show_image'], params)
    assert_form_action(:action => 'edit_image', :id => image.id.to_s)
  end

  def test_update_image
    contribution = @rolf.contribution
    image = images(:agaricus_campestris_image)
    obs = image.observations.first
    assert(obs)
    assert(obs.rss_log.nil?)
    new_name = 'new nāme.jpg'

    params = {
      "id" => image.id,
      "image" => {
        "when(1i)" => "2001",
        "when(2i)" => "5",
        "when(3i)" => "12",
        "copyright_holder" => "Rolf Singer",
        "notes"    => "",
        "original_name" => new_name
      }
    }
    post_requires_login(:edit_image, params)
    assert_response(:action => :show_image)
    assert_equal(contribution, @rolf.reload.contribution)

    assert(obs.reload.rss_log)
    assert(obs.rss_log.notes.include?('log_image_updated'))
    assert(obs.rss_log.notes.include?("user #{obs.user.login}"))
    assert(obs.rss_log.notes.include?("name #{RssLog.escape("Image ##{image.id}")}"))
    assert_equal(new_name, image.reload.original_name)
  end

  def test_remove_images
    obs = observations(:coprinus_comatus_obs)
    params = { :id => obs.id }
    assert_equal('rolf', obs.user.login)
    requires_user(:remove_images, [:observer, :show_observation], params)
    assert_form_action(:action => 'remove_images', :id => obs.id)
  end

  def test_reuse_image
    obs = observations(:agaricus_campestris_obs)
    params = { :mode => 'observation', :obs_id => obs.id }
    assert_equal('rolf', obs.user.login)
    requires_user(:reuse_image, [:observer, :show_observation], params)
    assert_form_action(:action => 'reuse_image', :mode => 'observation',
                       :obs_id => obs.id)
  end

  def test_reuse_image_by_id
    obs = observations(:agaricus_campestris_obs)
    image = images(:commercial_inquiry_image)
    assert(!obs.images.member?(image))
    params = {
      :mode   => 'observation',
      :obs_id => obs.id.to_s,
      :img_id => '3',
    }
    owner = obs.user.login
    assert_not_equal('mary', owner)
    requires_login(:reuse_image, params, "mary")
    assert_response(:controller => :observer, :action => :show_observation)
    assert(!obs.reload.images.member?(image))

    login(owner)
    get_with_dump(:reuse_image, params)
    assert_response(:controller => "observer", :action => "show_observation")
    assert(obs.reload.images.member?(image))
  end

  def test_upload_image
    contribution = @rolf.contribution
    setup_image_dirs
    obs = observations(:coprinus_comatus_obs)
    proj = projects(:bolete_project)
    proj.observations << obs
    img_count = obs.images.size
    file = FilePlus.new("#{RAILS_ROOT}/test/fixtures/images/Coprinus_comatus.jpg")
    file.content_type = 'image/jpeg'
    params = {
      :id => obs.id,
      :image => {
        "when(1i)" => "2007",
        "when(2i)"=>"3",
        "when(3i)"=>"29",
        :copyright_holder => "Douglas Smith",
        :notes => "Some notes."
      },
      :upload => {
        :image1 => file,
        :image2 => '',
        :image3 => '',
        :image4 => ''
      },
      :project => {
        # This is a good test, because Rolf doesn't belong to the Bolete project,
        # but we still want this image to attach to that project by default,
        # because the *observation* is attached to that project.
        "id_#{proj.id}" => '1'
      }
    }
    post_requires_user(:add_image, [:observer, :show_observation], params)
    assert_response(:controller => :observer, :action => :show_observation)
    assert_equal(contribution + 10, @rolf.reload.contribution)
    assert(obs.reload.images.size == (img_count + 1))
    message = :runtime_image_uploaded_image.t(:name => '#' + obs.images.last.id.to_s)
    assert_flash(/#{message}/)
    img = Image.last
    assert_obj_list_equal([obs], img.observations)
    assert_obj_list_equal([proj], img.projects)
  end

  # This is what would happen when user first opens form.
  def test_reuse_image_for_user
    requires_login(:reuse_image, :mode => 'profile')
    assert_response('reuse_image')
    assert_form_action(:action => 'reuse_image', :mode => 'profile')
  end

  # This would happen if user clicked on image.
  def test_reuse_image_for_user_post1
    image = images(:commercial_inquiry_image)
    params = { :mode => 'profile', :img_id => image.id.to_s }
    requires_login(:reuse_image, params)
    assert_response(:controller => :observer, :action => :show_user,
                    :id => @rolf.id)
    assert_equal(@rolf.id, session[:user_id])
    assert_equal(image.id, @rolf.reload.image_id)
  end

  # This would happen if user typed in id and submitted.
  def test_reuse_image_for_user_post2
    image = images(:commercial_inquiry_image)
    params = { :mode => 'profile', :img_id => image.id.to_s }
    post_requires_login(:reuse_image, params)
    assert_response(:controller => :observer, :action => :show_user,
                    :id => @rolf.id)
    assert_equal(@rolf.id, session[:user_id])
    assert_equal(image.id, @rolf.reload.image_id)
  end

  # Test setting anonymity of all image votes.
  def test_bulk_image_vote_anonymity_thingy
    img1 = images(:in_situ)
    img2 = images(:commercial_inquiry_image)
    img1.change_vote(@mary, 1, false)
    img2.change_vote(@mary, 2, true)
    img1.change_vote(@rolf, 3, true)
    img2.change_vote(@rolf, 4, false)

    assert_false(ImageVote.find_by_image_id_and_user_id(img1.id, @mary.id).anonymous)
    assert_true(ImageVote.find_by_image_id_and_user_id(img2.id, @mary.id).anonymous)
    assert_true(ImageVote.find_by_image_id_and_user_id(img1.id, @rolf.id).anonymous)
    assert_false(ImageVote.find_by_image_id_and_user_id(img2.id, @rolf.id).anonymous)

    requires_login(:bulk_vote_anonymity_updater)
    assert_response('bulk_vote_anonymity_updater')

    login('mary')
    post(:bulk_vote_anonymity_updater, :commit => :image_vote_anonymity_make_anonymous.l)
    assert_response(:controller => :account, :action => :prefs)
    assert_true(ImageVote.find_by_image_id_and_user_id(img1.id, @mary.id).anonymous)
    assert_true(ImageVote.find_by_image_id_and_user_id(img2.id, @mary.id).anonymous)
    assert_true(ImageVote.find_by_image_id_and_user_id(img1.id, @rolf.id).anonymous)
    assert_false(ImageVote.find_by_image_id_and_user_id(img2.id, @rolf.id).anonymous)

    login('rolf')
    post(:bulk_vote_anonymity_updater, :commit => :image_vote_anonymity_make_public.l)
    assert_response(:controller => :account, :action => :prefs)
    assert_true(ImageVote.find_by_image_id_and_user_id(img1.id, @mary.id).anonymous)
    assert_true(ImageVote.find_by_image_id_and_user_id(img2.id, @mary.id).anonymous)
    assert_false(ImageVote.find_by_image_id_and_user_id(img1.id, @rolf.id).anonymous)
    assert_false(ImageVote.find_by_image_id_and_user_id(img2.id, @rolf.id).anonymous)
  end

  def test_original_filename_visibility
    login('mary')

    @rolf.keep_filenames = :toss
    @rolf.save
    get(:show_image, :id => 6)
    assert_false(@response.body.include?('áč€εиts'))

    @rolf.keep_filenames = :keep_but_hide
    @rolf.save
    get(:show_image, :id => 6)
    assert_false(@response.body.include?('áč€εиts'))

    @rolf.keep_filenames = :keep_and_show
    @rolf.save
    get(:show_image, :id => 6)
    assert_true(@response.body.include?('áč€εиts'))

    login('rolf')

    @rolf.keep_filenames = :toss
    @rolf.save
    get(:show_image, :id => 6)
    assert_true(@response.body.include?('áč€εиts'))

    @rolf.keep_filenames = :keep_but_hide
    @rolf.save
    get(:show_image, :id => 6)
    assert_true(@response.body.include?('áč€εиts'))

    @rolf.keep_filenames = :keep_and_show
    @rolf.save
    get(:show_image, :id => 6)
    assert_true(@response.body.include?('áč€εиts'))
  end

  def test_bulk_original_filename_purge
    assert_equal(1, @rolf.id)
    imgs = Image.find(:all, :conditions => 'original_name != "" AND user_id = 1')
    assert(imgs.any?)

    login('rolf')
    get(:bulk_filename_purge)
    imgs = Image.find(:all, :conditions => 'original_name != "" AND user_id = 1')
    assert(imgs.empty?)
  end

  def test_project_checkboxes
    proj1 = projects(:eol_project)
    proj2 = projects(:bolete_project)
    obs1 = observations(:minimal_unknown)
    obs2 = observations(:detailed_unknown)
    img1 = images(:in_situ)
    img2 = images(:commercial_inquiry_image)
    assert_users_equal(@mary, obs1.user)
    assert_users_equal(@mary, obs2.user)
    assert_users_equal(@mary, img1.user)
    assert_users_equal(@rolf, img2.user)
    assert_obj_list_equal([],      obs1.projects)
    assert_obj_list_equal([proj2], obs2.projects)
    assert_obj_list_equal([proj2], img1.projects)
    assert_obj_list_equal([],      img2.projects)
    assert_obj_list_equal([@rolf, @mary, @katrina], proj1.user_group.users)
    assert_obj_list_equal([@dick], proj2.user_group.users)

    # NOTE: It is impossible, apparently, to get edit_image to fail,
    # so there is no way to test init_project_vars_for_reload().

    login('rolf')
    get(:add_image, :id => obs1.id)
    assert_response(:redirect)
    get(:add_image, :id => obs2.id)
    assert_response(:redirect)
    get(:edit_image, :id => img1.id)
    assert_response(:redirect)
    get(:edit_image, :id => img2.id)
    assert_project_checks(proj1.id => :unchecked, proj2.id => :no_field)

    login('mary')
    get(:add_image, :id => obs1.id)
    assert_project_checks(proj1.id => :unchecked, proj2.id => :no_field)
    get(:add_image, :id => obs2.id)
    assert_project_checks(proj1.id => :unchecked, proj2.id => :checked)
    get(:edit_image, :id => img1.id)
    assert_project_checks(proj1.id => :unchecked, proj2.id => :checked)
    get(:edit_image, :id => img2.id)
    assert_response(:redirect)

    login('dick')
    get(:add_image, :id => obs2.id)
    assert_project_checks(proj1.id => :no_field, proj2.id => :checked)
    get(:edit_image, :id => img1.id)
    assert_project_checks(proj1.id => :no_field, proj2.id => :checked)
    get(:edit_image, :id => img2.id)
    assert_response(:redirect)
    proj1.add_image(img1)
    get(:edit_image, :id => img1.id)
    assert_project_checks(proj1.id => :checked_but_disabled, proj2.id => :checked)
  end

  def assert_project_checks(project_states)
    for id, state in project_states
      assert_checkbox_state("project_id_#{id}", state)
    end
  end
end
