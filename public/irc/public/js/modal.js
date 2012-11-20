$(function() {
    var d = new Date();
    var da = d.toString().split(' ');
    var date = da[0]+' '+da[1]+' '+da[2]+' '+da[4];
    var lastlog = 'Last login: '+date+' on ttys000\n';
    var animated = false;
    function autoType(term, message, delay, finish) {
        animated = true;
        var c = 0;
        var interval = setInterval(function() {
            console.log(message);
            if (c < message.length) {
                term.insert(message[c++]);
            } else {
                clearInterval(interval);
                setTimeout(function() {
                    term.set_command('');
                    term.echo('root@smashthestack.org:~$ '+message);
                    term.set_prompt('');
                    animated = false
                    finish && finish();
                }, delay);
            }
        }, delay);
    }
    $('.modal-body').terminal(function(cmd, term) {
        var finish = false;
        var args = {command: cmd};
        var msg = '......';
        term.set_prompt('Connecting to server');
        autoType(term, msg, 200, function() {
            $('#connect-nick').val(args.command);  
            $('.btn.primary').trigger('click');
            term.disable();
        });
    }, {
        name: 'irc',
        greetings: 'Welcome to Smash The Stack!\n'+lastlog+'\n',
        onInit: function(term) {
            var msg = "./irc";
            term.set_prompt('root@smashthestack.org:~$ ');
            autoType(term, msg, 200, function() {
                term.echo("Please enter a nickname:");
                $('.clipboard').focus(); return false;
            });
        },
        keydown: function(e) {
            if (animated) {
                return false;
            }
        }
    });
});
