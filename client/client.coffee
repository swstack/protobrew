Meteor.subscribe 'entries', onComplete = ->
  Session.set('entryLoaded', true)

Meteor.subscribe('tags')

Meteor.subscribe('revisions')

Meteor.subscribe('allUserData')

Meteor.autosubscribe( ->
    Meteor.subscribe("userData");
);

Session.set('edit-mode', false)

# Todo: reloadEntry = true
navigate = (location, context) ->
    location = "/u/#{context}/#{location}" if context
    Router.navigate(location, true)

evtNavigate = (evt) ->
    evt.preventDefault()
    window.scrollTo(0,0)
    $a = $(evt.target).closest('a')
    href = $a.attr('href')
    localhost = document.location.host
    linkhost = $a[0].host
    if localhost == linkhost
        navigate(href)
    else
        window.open( href, '_blank')
   

## Nav

Deps.autorun ->
    # Random user call to force reactivity
    Meteor.user()
    if Meteor.user() && ! Meteor.user().username
        $('#new-user-modal').modal({'backdrop':'static', 'keyboard': false})


Template.newUserModal.rendered = () ->
    Session.set('selected-username', $('#initial-username-input').val() )

usernameTaken = (username) ->
    Meteor.users.find({username: username}).count() > 0

Template.newUserModal.continueDisabled = () ->
    Session.get('selected-username')
    username = $('#initial-username-input').val()
    username == '' || usernameTaken( username )

Template.newUserModal.usernameTaken = () ->
    Session.get('selected-username')
    username = $('#initial-username-input').val()
    usernameTaken( username )

Template.newUserModal.events =
    'keyup #initial-username-input': () ->
        Session.set('selected-username', $('#initial-username-input').val() )

    'click #new-username-button': (e) ->
        if ! $(e.target).hasClass('disabled')
            console.log( "click" );
            Meteor.call('updateUser', $("#initial-username-input").val(), (e) -> $("#new-user-modal").modal("hide") )

Template.leftNav.events =
    'click a.left-nav': evtNavigate

    'change #search-input': (evt) ->
        term = $(evt.target).val()
        navigate( '/search/' + term ) if term

    'click #usernav a': evtNavigate

    'click #userTabs > li' : (evt) ->
        $el = $(evt.currentTarget)
        Session.set( 'activeTab' , $el.attr('id'))

getSummaries = (entries) ->
    entries.map (e) ->
        
        text = $('<div>').html( e.text ).text()
        text = text.substring(0,200) + '...' if text.length > 204;
        
        {text: text, title: e.title}

Template.search.term = -> Session.get( 'search-term' )

Template.search.results = ->
    term = Session.get('search-term')

    return unless term
    
    entries = Entries.find( {text: new RegExp( term, "i" )} )
    getSummaries( entries )

Template.search.events
    'click a': evtNavigate

Template.tag.events
    'click a': evtNavigate


Template.tag.tag = ->
    Session.get( 'tag' )

Template.tag.results = ->
    tag = Session.get('tag')

    return unless tag
    
    entries = Entries.find( { tags: tag } )
    getSummaries( entries )


Template.leftNav.isActiveTab = (tab, options)->
    Session.equals "activeTab", tab 

Template.leftNav.isActivePanel = (panel, options)->
    Session.equals "activePanel", panel

Template.leftNav.term = -> 
    Session.get( 'search-term' )

Template.leftNav.pageIs = (u) ->
    page = Session.get('title')
    return u == "/" if page == undefined
    return u == page

Template.leftNav.edited = () ->
    revisions = Revisions.find({author: Meteor.userId()}, {entryId: true}).fetch()
    ids = _.map( revisions, (r) -> r.entryId )
    entries = Entries.find({_id: {$in: ids}}).fetch()
    _.sortBy( entries, (e) -> e.date ).reverse()


Template.leftNav.starred = () ->
    user = Meteor.user()
    if ! user 
        return
    else
        starredPages = user.profile.starredPages
        if ! starredPages
            return
        starred =  Entries.find({ _id :{$in: starredPages}}).fetch()
        if ! starred or starred.length == 0
          return # starred = {starred:["nothing"]} #would need to make this not a link
        return starred

Handlebars.registerHelper( 'entryLink', (entry) ->
    unless entry.context then "/#{entry.title}" else "/u/#{entry.context}/#{entry.title}"
)

## Entry

Template.entry.title = ->
    Session.get("title")

Template.entry.userContext = ->
    Session.get("context")

Template.entry.editable = ->
    entry = Session.get('entry')
    context = Session.get("context")
    user  = Meteor.user()
    editable( entry, user, context )

Template.entry.adminable = ->
    context = Session.get("context")
    user  = Meteor.user()
    adminable( user, context )

Template.entry.viewable = ->
    entry = Session.get('entry')
    context = Session.get("context")
    user  = Meteor.user()
    viewable( entry, user, context )

Template.entry.modeIs = (v) ->
    return v == Session.get('entry').mode

Template.entry.entry = ->

    title = Session.get("title")
    context = Session.get('context')
    $("#sidebar").html('') #clear sidebar of previous state
    if title
        entry = Entries.findOne({title: title, context: context})
        if entry
            Session.set('entry', entry )
            Session.set('entry_id', entry._id )

            source = $('<div>').html( entry.text )
            titles = stackTitles( filterHeadlines( source.find( 'h1' ) ) )
            titles.unshift( {id: 0, target: "article-title", title: Session.get('title') } )

            if titles.length > 0
                for e, i in source.find('h1,h2,h3,h4,h5')
                    e.id = "entry-title-" + (i + 1)

            ul = $('<ul>')
            buildNav( ul, titles)
            $("#sidebar").html(ul)

            entry.text = source.html()
            entry
        else
            Session.set( 'entry', {} )
            Session.set( 'entry_id', null )
            Session.get('entryLoaded')


Template.entry.edit_mode = ->
    Session.get('edit-mode')

Template.main.modeIs = (mode) ->
    Session.get('mode') == mode;

Template.main.loginConfigured = () ->
    if Accounts.loginServicesConfigured()
        return true;
    else
        return false;

Template.index.content = ->
    entry = Entries.findOne({title:"index"})
    $("#sidebar").html('') #clear sidebar of previous state
    if entry
        Session.set('entry', entry )
        Session.set('entry_id', entry._id )

        source = $('<div>').html( entry.text )
        titles = stackTitles( source.find( 'h1' ) )

        if titles.length > 0
            for e, i in source.find('h1,h2,h3,h4,h5')
                e.id = "entry-title-" + (i + 1)

        ul = $('<ul>')
        buildNav( ul, titles )

        $("#sidebar").html(ul)

        entry

Template.index.events
    'click a.entry-link': evtNavigate

Template.editEntry.events
    'focus #entry-tags': (evt) ->
        $("#tag-init").show()

Template.editEntry.rendered = ->
    el = $( '#entry-text' )
    el.redactor(
        imageUpload: '/images'
        buttons: ['html', '|', 'formatting', '|', 'bold', 'italic', 'deleted', '|', 
            'unorderedlist', 'orderedlist', 'outdent', 'indent', '|',
            'image', 'table', 'link', '|',
            'fontcolor', 'backcolor', '|', 'alignment', '|', 'horizontalrule', '|',
            'save', 'cancel', 'delete'],
        # buttonsCustom:
        #     save:
        #         title: 'Save'
        #         callback: saveEntry
        #     cancel:
        #         title: 'Cancel'
        #         callback: ->
        #             Session.set("edit-mode", false)
        #     delete:
        #         title: 'Delete'
        #         callback: deleteEntry
        focus: true
        autoresize: true
        filepicker: (callback) ->

            filepicker.setKey('AjmU2eDdtRDyMpagSeV7rz')

            filepicker.pick({mimetype:"image/*"}, (file) ->
                filepicker.store(file, {location:"S3", path: Meteor.userId() + "/" + file.filename },
                (file) -> callback( filelink: file.url )))
    )

    window.scrollTo(0,Session.get('y-offset'))

    tags = Tags.find({})
    entry = Session.get('entry')

    $('#entry-tags').textext({
        plugins : 'autocomplete suggestions tags',
        tagsItems: if entry then entry.tags else []
        suggestions: tags.map (t) -> t.name
    });

deleteEntry = (evt) ->
    entry = Session.get('entry')
    if entry && confirm( "Are you sure you want to delete #{entry.title}?")
        Entries.remove({_id: entry._id})
        Session.set('edit-mode', false)

saveEntry = (evt) ->
    reroute = ( e ) ->
        navigate( entry.title, Session.get( "context" ) ) unless entry.title == "home"

    title = Session.get('title')

    entry = {
        'title': title
        'text': rewriteLinks( $('#entry-text').val() )
        'mode': $('#mode').val()
    }

    tags = $('#entry-tags').nextAll('input[type=hidden]').val()

    if tags
        tags = JSON.parse(tags)
        entry.tags = tags;
        Tags.insert({'name':tag}) for tag in tags

    eid = Session.get('entry_id')
    entry._id = eid if eid

    context = Session.get('context')

    Meteor.call('saveEntry', entry, context, reroute)
    Entries.update({_id: entry._id}, entry)
    Session.set("edit-mode", false)


Template.entry.events

    'click #new_page': (evt) ->
        evt.preventDefault()
        console.log('event')
        Meteor.call('createNewPage', 
           (error, pageName) ->
                console.log(error, pageName);
                #TODO: fix non-editable navigate
                navigate(pageName)
        )

    'click #toggle_star': (evt) ->
        evt.preventDefault()
        user  = Meteor.user()
        starredPages = user.profile.starredPages
        entryId = Session.get('entry_id')
        if entryId in starredPages
            console.log('match pulling')
            Meteor.users.update(Meteor.userId(), {
                $pull: {'profile.starredPages': entryId}
            })
        else
            console.log('no match pushing')
            Meteor.users.update(Meteor.userId(), {
                $push: {'profile.starredPages': entryId}
            })

    'click li.article-tag a': (evt) ->
        evt.preventDefault()
        tag = $(evt.target).text()
        navigate( '/tag/' + tag ) if tag

    'click a.entry-link': (e) ->
        evtNavigate(e) unless Session.get('edit-mode')

    'click #sidenav_btn': (evt) ->
        evt.preventDefault()
        jPM = $.jPanelMenu(
            menu: "#leftNavContainer"
            trigger: "#sidenav_btn"
            openPosition: '235px'
            closeOnContentClick: false
            keyboardShortcuts: false
            afterOpen: -> $('a.left-nav').click( evtNavigate )
        )
        if jPM.isOpen()
            jPM.off()
        else
            jPM.on()
            #todo: Selah review below code
            #tab fix for tab functionality in jPanelMenu/sidebar
            # issue: cloned ids need unique names for the bootstrap
            # tab code to wrok
            # soltion - change the ids in question to have _panel appended
            $( "#jPanelMenu-menu .tabButton" ).each ->
                tab_id_name = $(this).attr('href')
                $(this).attr('href', tab_id_name+'_panel')

            $( "#jPanelMenu-menu .tab-pane" ).each ->
                tab_id_name = $(this).attr('id')
                $(this).attr('id', tab_id_name+'_panel')


    'click #edit': (evt) ->
        Session.set( 'y-offset', window.pageYOffset )
        evt.preventDefault()
        Session.set('edit-mode', true )

    'click #save': (evt) ->
        evt.preventDefault()
        saveEntry( evt )

    'click #cancel': (evt) ->
        evt.preventDefault()
        Session.set("edit-mode", false)

    'click #delete': (evt) ->
        evt.preventDefault()
        deleteEntry(evt)

    'click #article-title': (evt) ->

        entry = Session.get('entry')
        context = Session.get("context")
        user  = Meteor.user()
        return unless editable( entry, user, context )

        $el = $(evt.target)
        $in = $("<input class='entry-title-input'/>")
        $in.val( $el.text().trim() )
        $el.replaceWith($in)
        $in.focus()

        updateTitle = (e, force = false) ->
            if force || e.target != $el[0] && e.target != $in[0]
                if $in.val() != $el.text()
                    Meteor.call('updateTitle', Session.get('entry'), $in.val())
                    $el.html($in.val())
                    navigate($in.val())

                $in.replaceWith($el)
                $(document).off('click')

        cancel = (e, force = false) ->
            if force || e.target != $el[0] && e.target != $in[0]
                $in.replaceWith($el)
                $(document).off('click')

        $(document).on('click', cancel)

        $in.on("keyup", (e) ->
            updateTitle(e, true) if e.keyCode == 13
            cancel(e, true) if e.keyCode == 27
        )

Template.profile.user = ->
    Meteor.user()

Template.profile.events
    'click #save': (evt) ->
        result = Meteor.call('updateUser', $("#username").val(), (e) -> console.log( e ) )


Template.user.info = ->
    Meteor.user()

rewriteLinks = ( text ) ->
    $html = $('<div>')
    $html.html( text )

    for el in $html.find( 'a' )
        href = $(el).attr( 'href' )
        if href
            href = href.replace( /https?:\/\/([^\/.]+)$/, '/$1' )
            $(el).attr( 'href', href )
            $(el).addClass( 'entry-link' )

    $html.html()


EntryRouter = Backbone.Router.extend({
    routes: {
        "search/:term": "search"
        "tag/:tag": "tag",
        "profile": "profile",
        "images": "images",
        "u/:user/:title": "userSpace",
        ":title": "main",
        "": "index"
    },
    index: ->
        Session.set("mode", 'index')
        Session.set("title", undefined)
    profile: (term) ->
        Session.set( 'mode', 'profile' )
    search: (term) ->
        Session.set( 'mode', 'search' )
        Session.set( 'search-term', decodeURIComponent( term ) )
    tag: (tag) ->
        Session.set( 'mode', 'tag' )
        Session.set( 'tag', decodeURIComponent( tag ) )
    userSpace: (username, title) ->
        Session.set("mode", 'entry')
        Session.set("context", username)
        Session.set("title", decodeURIComponent( title ))
    main: (title) ->
        Session.set("mode", 'entry')
        Session.set("context", null)
        Session.set("title", decodeURIComponent( title ))
    setTitle: (title) ->
        this.navigate(title, true)
})

Router = new EntryRouter

Meteor.startup ->
    Backbone.history.start pushState: true
    Session.set('activeTab', 'editedTab')
  
##################################
## NAV

Template.sidebar.navItems = ->
    Session.get('sidebar')

stackTitles = (items, cur, counter) ->

    cur = 1 if cur == undefined
    counter ?= 1

    next = cur + 1

    for elem, index in items
        elem = $(elem)
        children  =  filterHeadlines( elem.nextUntil( 'h' + cur, 'h' + next ) )

        d = {};
        d.title = elem.text()
        # d.y  = elem.offset().top
        d.id = counter++
        d.target = "entry-title-#{d.id}"

        d.style = "top" if cur == 0

        d.children = stackTitles( children, next, counter ) if children.length > 0

        d

filterHeadlines = ( $hs ) ->
    _.filter( $hs, ( h ) -> $(h).text().match(/[^\s]/) )

buildNav = ( ul, items ) ->
    for child, index in items

        li = $( "<li>" )
        $( ul ).append( li )
        $a = $("<a/>")
        $a.attr( "id", "nav-title-" + child.id )
        $a.data("target", child.target )
        $a.addClass( child.style )

        $a.on( "click", ->
            id = this.id
            target_id = $(this).data('target')
            offset = $('#' + target_id).offset()
            adjust = if Session.get( 'edit-mode' ) then 70 else 20
            $( 'html,body' ).animate( { scrollTop: offset.top - adjust }, 350 )
        )

        $a.attr( 'href', 'javscript:void(0)' )
        $a.html( child.title )
        
        li.append( $a )

        if child.children
            subUl = document.createElement( 'ul' )
            li.append( subUl )
            buildNav( subUl, child.children )

highlightNav = ->

    pos = $(window).scrollTop( )
    headlines = $('h1, h2, h3, h4, h5')

    # id = null

    for headline in headlines
        if $(headline).offset().top + 20 > pos
            id = headline.id.replace( /entry/, "nav" )
            break

    el = $("#" + id)

    el.parents( 'ul' ).find( 'a' ).removeClass( 'selected' )
    # el.parents( 'li' ).last().addClass( 'selected' )
    el.addClass( 'selected' )


scrollLast = +new Date()


$(window).scroll ->
    if +new Date() - scrollLast > 50
        scrollLast = +new Date();
        highlightNav()


Meteor.saveFile = (blob, name, path, type, callback) ->
  fileReader = new FileReader()
  encoding = 'binary'
  type = type || 'binary'

  switch type
    when 'text'
      method = 'readAsText'
      encoding = 'utf8'
    when 'binary'
      method = 'readAsBinaryString'
      encoding = 'binary'
    else
      method = 'readAsBinaryString'
      encoding = 'binary'

  fileReader.onload = (file) ->
    result = Meteor.call('saveFile', file.srcElement.result, name, path, encoding, (e) ->
        callback( { filelink: "/user-images/#{Meteor.userId()}/#{name}" } )
    )

  fileReader[method](blob)

# call this after initial code load has run and it will print out all templates that re-render
# logRenders = ->
#   _.each Template, (template, name) ->
#     oldRender = template.rendered
#     counter = 0
#     template.rendered = ->
#       console.log name, "render count: ", ++counter
#       oldRender and oldRender.apply(this, arguments_)