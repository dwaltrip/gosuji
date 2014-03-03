var socket = null;
var modal = new Modal({ closeButton: false });

$(document).ready(function() {
    console.log('$(document).ready handler');

    // join open game
    $('#open-games-table').on('click.join_game', '.join-game-link', function(e) {
        e.preventDefault();
        modal.open({ content: prep_join_game_modal_content($(this)) });
    });
    $(modal.selector).on('click', '.join-game-content .ok-button', function(e) {
        $.ajax({
            type: 'POST',
            url: $(this).data('action_url'),
            beforeSend: function(xhr) {
                xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))
            },
            dataType: 'json',
            success: join_game_callback
        });
        modal.close();
    });
    $(modal.selector).on('click', '.join-game-content .cancel-button', function(e) { modal.close(); });

    socket = get_socket();
    socket.emit('subscribe-to-updates', { room_id: window.room_id });
});

function prep_join_game_modal_content(link_elem) {
    var $popup_content = $('#join-game-content-wrapper .join-game-content').clone();

    $popup_content.find('.ok-button').data('action_url', link_elem.attr('href'));
    game_settings = link_elem.data('settings');

    for(var setting in game_settings) {
        // update $popup_content
    }

    $popup_content.find('#challenged-player').text(link_elem.data('username'));

    return $popup_content;
}

function join_game_callback(data) {
    console.log('-- join_game_callback -- data:', data);
    if (data.join_game_succeeded) {
        window.location.href = data.game_url;
    }
    else if (data.login_url) {
        window.location.href = data.login_url;
    }
}

function get_socket() {
    console.log('-- sockjs_url: ' + window.sockjs_url + '\n');
    var sockjs = new SockjsClient(window.sockjs_url);

    sockjs.on('connect', function() {
        console.log("sockjs successfully connected with protocol '" + sockjs.protocol + "'");
    });

    sockjs.on('close', function() {
        console.log("sockjs connection close. callback args: " + Array.prototype.slice.call(arguments));
    });

    sockjs.on('message', function(data) {
        console.log("inside sockjs.on('message', cb) callback, data= " + JSON.stringify(data));
    });

    return sockjs;
}

