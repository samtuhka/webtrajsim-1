$ = require 'jquery'
P = require 'bluebird'
seqr = require './seqr.ls'
{runScenario, newEnv} = require './scenarioRunner.ls'
scenario = require './scenario.ls'
sounds = require './sounds.ls'

L = (s) -> s

runUntilPassed = seqr.bind (scenarioLoader, {passes=2, maxRetries=5}={}) ->*
	currentPasses = 0
	for retry from 1 til Infinity
		task = runScenario scenarioLoader
		result = yield task.get \done
		currentPasses += result.passed

		doQuit = currentPasses >= passes or retry > maxRetries
		#if not doQuit
		#	result.outro \content .append $ L "<p>Let's try that again.</p>"
		yield task
		if doQuit
			break

shuffleArray = (a) ->
	i = a.length
	while (--i) > 0
		j = Math.floor (Math.random()*(i+1))
		[a[i], a[j]] = [a[j], a[i]]
	return a


export mulsimco2015 = seqr.bind ->*
	env = newEnv!
	yield scenario.participantInformation yield env.get \env
	env.let \destroy
	yield env

	#yield runScenario scenario.runTheLight
	yield runUntilPassed scenario.closeTheGap, passes: 3

	yield runUntilPassed scenario.throttleAndBrake
	yield runUntilPassed scenario.speedControl
	yield runUntilPassed scenario.blindSpeedControl

	yield runUntilPassed scenario.followInTraffic
	yield runUntilPassed scenario.blindFollowInTraffic

	ntrials = 4
	scenarios = []
		.concat([scenario.followInTraffic]*ntrials)
		.concat([scenario.blindFollowInTraffic]*ntrials)
	scenarios = shuffleArray scenarios

	for scn in scenarios
		yield runScenario scn

	intervals = shuffleArray [1, 1, 2, 2, 3, 3]
	for interval in intervals
		yield runScenario scenario.forcedBlindFollowInTraffic, interval: interval

	env = newEnv!
	yield scenario.experimentOutro yield env.get \env
	env.let \destroy
	yield env


laneChecker = (scenario) ->
	(env, ...args) ->
		env.opts.forceSteering = true
		task = scenario env, ...args
		task.get(\scene).then seqr.bind (scene) ->*
			return if not scene.player
			warningSound = yield sounds.WarningSound env
			lanecenter = scene.player.physical.position.x
			scene.afterPhysics (dt) ->
				drift = Math.abs lanecenter - scene.player.physical.position.x
				if drift < 0.5
					warningSound.stop()
				else
					warningSound.start()
				return if drift < 1.0
				task.let \done, passed: false, outro:
					title: env.L "Oops!"
					content: env.L "You drove out of your lane."
			scene.onExit ->
				warningSound.stop()
		return task

export blindFollow17 = seqr.bind ->*
	yield runUntilPassed laneChecker scenario.stayOnLane, passes: 3
	return
	env = newEnv!
	yield scenario.participantInformation yield env.get \env
	env.let \destroy
	yield env

	#yield runScenario scenario.runTheLight
	yield runUntilPassed laneChecker scenario.closeTheGap, passes: 3

	yield runUntilPassed laneChecker scenario.throttleAndBrake
	yield runUntilPassed laneChecker scenario.speedControl
	yield runUntilPassed laneChecker scenario.blindSpeedControl

	yield runUntilPassed laneChecker scenario.followInTraffic
	yield runUntilPassed laneChecker scenario.blindFollowInTraffic

	ntrials = 4
	scenarios = []
		.concat([scenario.followInTraffic]*ntrials)
		.concat([scenario.blindFollowInTraffic]*ntrials)
	scenarios = shuffleArray scenarios

	for scn in scenarios
		yield runScenario laneChecker scn

	intervals = shuffleArray [1, 1, 2, 2, 3, 3]
	for interval in intervals
		yield runScenario laneChecker scenario.forcedBlindFollowInTraffic, interval: interval

	env = newEnv!
	yield scenario.experimentOutro yield env.get \env
	env.let \destroy
	yield env

export defaultExperiment = mulsimco2015

export freeDriving = seqr.bind ->*
	yield runScenario scenario.freeDriving

runWithNewEnv = seqr.bind (scenario, ...args) ->*
	envP = newEnv!
	env = yield envP.get \env
	ret = yield scenario env, ...args
	envP.let \destroy
	yield envP
	return ret

export blindPursuit = seqr.bind ->*
	yield runWithNewEnv scenario.participantInformationBlindPursuit
	totalScore =
		correct: 0
		incorrect: 0
	yield runWithNewEnv scenario.soundSpook, preIntro: true

	runPursuitScenario = seqr.bind (...args) ->*
		task = runScenario ...args
		env = yield task.get \env
		res = yield task.get \done

		totalScore.correct += res.result.score.correct
		totalScore.incorrect += res.result.score.incorrect
		totalPercentage = totalScore.correct/(totalScore.correct + totalScore.incorrect)*100
		res.outro \content .append $ env.L "%blindPursuit.totalScore", score: totalPercentage
		yield task
		return res
	res = yield runPursuitScenario scenario.pursuitDiscriminationPractice
	frequency = res.result.estimatedFrequency
	nBlocks = 2
	trialsPerBlock = 2
	for block from 0 til nBlocks
		for trial from 0 til trialsPerBlock
			yield runPursuitScenario scenario.pursuitDiscrimination, frequency: frequency
		yield runWithNewEnv scenario.soundSpook

	env = newEnv!
	yield scenario.experimentOutro (yield env.get \env), (env) ->
		totalPercentage = totalScore.correct/(totalScore.correct + totalScore.incorrect)*100
		@ \content .append env.L '%blindPursuit.finalScore', score: totalPercentage
	env.let \destroy
	yield env

deparam = require 'jquery-deparam'
export singleScenario = seqr.bind ->*
	# TODO: The control flow is a mess!
	opts = deparam window.location.search.substring 1
	scn = scenario[opts.singleScenario]
	while true
		yield runScenario scn



export memkiller = seqr.bind !->*
	#loader = scenario.minimalScenario
	loader = scenario.blindFollowInTraffic
	#loader = scenario.freeDriving
	#for i from 1 to 1
	#	console.log i
	#	scn = loader()
	#	yield scn.get \scene
	#	scn.let \run
	#	scn.let \done
	#	yield scn
	#	void

	for i from 1 to 10
		console.log i
		yield do seqr.bind !->*
			runner = runScenario loader
			[scn] = yield runner.get 'ready'
			console.log "Got scenario"
			[intro] = yield runner.get 'intro'
			if intro.let
				intro.let \accept
			yield P.delay 1000
			scn.let 'done', passed: false, outro: title: "Yay"
			runner.let 'done'
			[outro] = yield runner.get 'outro'
			outro.let \accept
			console.log "Running"
			yield runner
			console.log "Done"

		console.log "Memory usage: ", window?performance?memory?totalJSHeapSize/1024/1024
		if window.gc
			for i from 0 til 10
				window.gc()
			console.log "Memory usage (after gc): ", window?performance?memory?totalJSHeapSize/1024/1024
	return i

export logkiller = seqr.bind !->*
	scope = newEnv!
	env = yield scope.get \env
	for i from 0 to 1000
		env.logger.write foo: "bar"

	scope.let \destroy
	yield scope
	console.log "Done"

